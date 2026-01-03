#!/usr/bin/env bash

# aws_rds_cmd - Utility helper for RDS operations
#
# This executable handles RDS console viewing and connections.
# Designed to be called from fzf keybindings and other scripts.
#
# USAGE:
#   aws_rds_cmd view-instance <db-instance-identifier>
#   aws_rds_cmd view-cluster <db-cluster-identifier>
#   aws_rds_cmd connect-instance <db-instance-identifier>
#   aws_rds_cmd connect-cluster <db-cluster-identifier>
#
# DESCRIPTION:
#   Provides console viewing and psql connection functionality for RDS databases.

set -euo pipefail

# Source shared core utilities
_aws_rds_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_rds_cmd_source_dir/aws_core.sh"

# _aws_rds_view_instance()
#
# Open RDS DB instance in AWS Console
#
# PARAMETERS:
#   $1 - DB instance identifier (required)
#
# DESCRIPTION:
#   Opens the specified RDS instance in the default web browser
#   via the AWS Console URL
#
_aws_rds_view_instance() {
	local instance="${1:-}"

	if [ -z "$instance" ]; then
		gum log --level error "DB instance identifier is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/rds/home?region=${region}#database:id=${instance}"
}

# _aws_rds_view_cluster()
#
# Open RDS DB cluster in AWS Console
#
# PARAMETERS:
#   $1 - DB cluster identifier (required)
#
# DESCRIPTION:
#   Opens the specified RDS cluster in the default web browser
#   via the AWS Console URL
#
_aws_rds_view_cluster() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "DB cluster identifier is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/rds/home?region=${region}#database:id=${cluster};is-cluster=true"
}

# _aws_rds_connect_instance()
#
# Connect to RDS DB instance using psql with IAM authentication
#
# PARAMETERS:
#   $1 - DB instance identifier (required)
#
# DESCRIPTION:
#   Connects to a PostgreSQL RDS instance using psql client with IAM auth token.
#   Requires IAM database authentication to be enabled and psql client installed.
#
_aws_rds_connect_instance() {
	local instance="${1:-}"

	if [ -z "$instance" ]; then
		gum log --level error "DB instance identifier is required"
		exit 1
	fi

	# Get instance details
	gum log --level info "Fetching instance details..."
	local instance_info
	instance_info=$(aws rds describe-db-instances \
		--db-instance-identifier "$instance" \
		--output json 2>&1)

	if [ $? -ne 0 ]; then
		gum log --level error "Failed to describe instance: $instance"
		exit 1
	fi

	# Extract connection details
	local endpoint port engine username iam_enabled
	endpoint=$(echo "$instance_info" | jq -r '.DBInstances[0].Endpoint.Address')
	port=$(echo "$instance_info" | jq -r '.DBInstances[0].Endpoint.Port')
	engine=$(echo "$instance_info" | jq -r '.DBInstances[0].Engine')
	username=$(echo "$instance_info" | jq -r '.DBInstances[0].MasterUsername')
	iam_enabled=$(echo "$instance_info" | jq -r '.DBInstances[0].IAMDatabaseAuthenticationEnabled')

	# Check for PostgreSQL engine
	if [[ ! "$engine" =~ ^(postgres|aurora-postgresql) ]]; then
		gum log --level error "Only PostgreSQL databases are supported"
		gum log --level info "Engine: $engine"
		exit 1
	fi

	# Check if IAM auth is enabled
	if [ "$iam_enabled" != "true" ]; then
		gum log --level error "IAM database authentication is not enabled for this instance"
		gum log --level info "Enable IAM authentication in RDS console or use password-based connection"
		exit 1
	fi

	# Check if psql is installed
	if ! command -v psql >/dev/null 2>&1; then
		gum log --level error "psql client not found"
		gum log --level info "Install PostgreSQL client: brew install postgresql"
		exit 1
	fi

	# Generate IAM auth token
	gum log --level info "Generating IAM auth token..."
	local region
	region=$(_get_aws_region)

	local token
	token=$(aws rds generate-db-auth-token \
		--hostname "$endpoint" \
		--port "$port" \
		--username "$username" \
		--region "$region" 2>&1)

	if [ $? -ne 0 ]; then
		gum log --level error "Failed to generate auth token"
		exit 1
	fi

	# Connect to database
	gum log --level info "Connecting to $instance ($endpoint:$port) as $username..."

	export PGHOST="$endpoint"
	export PGPORT="$port"
	export PGUSER="$username"
	export PGPASSWORD="$token"
	export PGSSLMODE="require"

	# Connect using psql
	psql -d postgres
}

# _aws_rds_connect_cluster()
#
# Connect to RDS DB cluster using psql with IAM authentication
#
# PARAMETERS:
#   $1 - DB cluster identifier (required)
#
# DESCRIPTION:
#   Connects to an Aurora PostgreSQL cluster using psql client with IAM auth token.
#   Requires IAM database authentication to be enabled and psql client installed.
#   Connects to writer endpoint.
#
_aws_rds_connect_cluster() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "DB cluster identifier is required"
		exit 1
	fi

	# Get cluster details
	gum log --level info "Fetching cluster details..."
	local cluster_info
	cluster_info=$(aws rds describe-db-clusters \
		--db-cluster-identifier "$cluster" \
		--output json 2>&1)

	if [ $? -ne 0 ]; then
		gum log --level error "Failed to describe cluster: $cluster"
		exit 1
	fi

	# Extract connection details (writer endpoint)
	local endpoint port engine username iam_enabled
	endpoint=$(echo "$cluster_info" | jq -r '.DBClusters[0].Endpoint')
	port=$(echo "$cluster_info" | jq -r '.DBClusters[0].Port')
	engine=$(echo "$cluster_info" | jq -r '.DBClusters[0].Engine')
	username=$(echo "$cluster_info" | jq -r '.DBClusters[0].MasterUsername')
	iam_enabled=$(echo "$cluster_info" | jq -r '.DBClusters[0].IAMDatabaseAuthenticationEnabled')

	# Check for PostgreSQL engine
	if [[ ! "$engine" =~ ^(aurora-postgresql) ]]; then
		gum log --level error "Only Aurora PostgreSQL clusters are supported"
		gum log --level info "Engine: $engine"
		exit 1
	fi

	# Check if IAM auth is enabled
	if [ "$iam_enabled" != "true" ]; then
		gum log --level error "IAM database authentication is not enabled for this cluster"
		gum log --level info "Enable IAM authentication in RDS console or use password-based connection"
		exit 1
	fi

	# Check if psql is installed
	if ! command -v psql >/dev/null 2>&1; then
		gum log --level error "psql client not found"
		gum log --level info "Install PostgreSQL client: brew install postgresql"
		exit 1
	fi

	# Generate IAM auth token
	gum log --level info "Generating IAM auth token..."
	local region
	region=$(_get_aws_region)

	local token
	token=$(aws rds generate-db-auth-token \
		--hostname "$endpoint" \
		--port "$port" \
		--username "$username" \
		--region "$region" 2>&1)

	if [ $? -ne 0 ]; then
		gum log --level error "Failed to generate auth token"
		exit 1
	fi

	# Connect to database
	gum log --level info "Connecting to cluster $cluster ($endpoint:$port) as $username..."

	export PGHOST="$endpoint"
	export PGPORT="$port"
	export PGUSER="$username"
	export PGPASSWORD="$token"
	export PGSSLMODE="require"

	# Connect using psql
	psql -d postgres
}

# Command router
case "${1:-}" in
view-instance)
	shift
	_aws_rds_view_instance "$@"
	;;
view-cluster)
	shift
	_aws_rds_view_cluster "$@"
	;;
connect-instance)
	shift
	_aws_rds_connect_instance "$@"
	;;
connect-cluster)
	shift
	_aws_rds_connect_cluster "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_rds_cmd - Utility commands for RDS operations

CONSOLE VIEWS:
    aws_rds_cmd view-instance <db-instance-identifier>
    aws_rds_cmd view-cluster <db-cluster-identifier>

DATABASE CONNECTION:
    aws_rds_cmd connect-instance <db-instance-identifier>
    aws_rds_cmd connect-cluster <db-cluster-identifier>

DESCRIPTION:
    View commands open RDS resources in the AWS Console via the default browser.
    Connection commands use psql with IAM authentication (PostgreSQL only).

EXAMPLES:
    # Console views
    aws_rds_cmd view-instance my-database
    aws_rds_cmd view-cluster my-aurora-cluster

    # Database connections
    aws_rds_cmd connect-instance my-postgres-db
    aws_rds_cmd connect-cluster my-aurora-cluster

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_rds_cmd {view-*|connect-*} [args]"
	gum log --level info "Run 'aws_rds_cmd --help' for more information"
	exit 1
	;;
esac
