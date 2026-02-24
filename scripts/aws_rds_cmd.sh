#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

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
	local instance_info
	instance_info=$(
		gum spin --title "Getting AWS RDS Instance Details..." -- \
			aws rds describe-db-instances \
			--db-instance-identifier "$instance" \
			--output json 2>&1
	)

	# shellcheck disable=SC2181
	if [ $? -ne 0 ]; then
		gum log --level error "Failed to describe instance: $instance"
		gum log --level info "Check that the instance exists and you have permissions"
		gum log --level info "Required IAM permissions: rds:DescribeDBInstances"
		gum log --level info "Run 'aws rds describe-db-instances' to verify access"
		exit 1
	fi

	# Extract connection details
	local endpoint port engine username iam_enabled
	endpoint=$(echo "$instance_info" | jq -r '.DBInstances[0].Endpoint.Address')
	port=$(echo "$instance_info" | jq -r '.DBInstances[0].Endpoint.Port')
	engine=$(echo "$instance_info" | jq -r '.DBInstances[0].Engine')
	username=$(echo "$instance_info" | jq -r '.DBInstances[0].MasterUsername')
	iam_enabled=$(echo "$instance_info" | jq -r '.DBInstances[0].IAMDatabaseAuthenticationEnabled')

	# Check for valid endpoint
	if [ -z "$endpoint" ] || [ "$endpoint" = "null" ]; then
		gum log --level error "Instance endpoint not available"
		gum log --level info "The instance may not be ready or in 'available' state"
		gum log --level info "Check instance status with: aws rds describe-db-instances --db-instance-identifier $instance"
		exit 1
	fi

	# Check for PostgreSQL engine
	if [[ ! "$engine" =~ ^(postgres|aurora-postgresql) ]]; then
		gum log --level error "Only PostgreSQL databases are supported for IAM authentication"
		gum log --level info "Current engine: $engine"
		gum log --level info "Supported engines: postgres, aurora-postgresql"
		exit 1
	fi

	# Check if IAM auth is enabled
	if [ "$iam_enabled" != "true" ]; then
		gum log --level error "IAM database authentication is not enabled for this instance"
		gum log --level info "To enable IAM authentication:"
		gum log --level info "1. Modify the DB instance in RDS console"
		gum log --level info "2. Enable 'Password and IAM database authentication'"
		gum log --level info "3. Apply changes (may require instance restart)"
		exit 1
	fi

	# Check if psql is installed
	if ! command -v psql >/dev/null 2>&1; then
		gum log --level error "psql client not found"
		gum log --level info "Install PostgreSQL client:"
		gum log --level info "macOS: brew install postgresql"
		gum log --level info "Ubuntu/Debian: apt-get install postgresql-client"
		gum log --level info "Amazon Linux: yum install postgresql"
		exit 1
	fi

	# Generate IAM auth token
	gum log --level info "Generating IAM auth token..."
	local region
	region=$(_get_aws_region)

	local token
	token=$(
		gum spin --title "Generating IAM Auth Token..." -- \
			aws rds generate-db-auth-token \
			--hostname "$endpoint" \
			--port "$port" \
			--username "$username" \
			--region "$region" 2>&1
	)

	# shellcheck disable=SC2181
	if [ $? -ne 0 ]; then
		gum log --level error "Failed to generate IAM auth token"
		gum log --level info "Check your AWS credentials and IAM permissions"
		gum log --level info "Required IAM permissions: rds-db:connect"
		gum log --level info "IAM policy resource: arn:aws:rds-db:${region}:*:dbuser:*/${username}"
		gum log --level info "Run 'aws sts get-caller-identity' to verify your identity"
		exit 1
	fi

	# Connect to database
	gum log --level info "Connecting to AWS RDS Instance $instance ($endpoint:$port) as $username..."

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
	local cluster_info
	cluster_info=$(
		gum spin --title "Getting AWS RDS Cluster Details..." -- \
			aws rds describe-db-clusters \
			--db-cluster-identifier "$cluster" \
			--output json 2>&1
	)

	# shellcheck disable=SC2181
	if [ $? -ne 0 ]; then
		gum log --level error "Failed to describe cluster: $cluster"
		gum log --level info "Check that the cluster exists and you have permissions"
		gum log --level info "Required IAM permissions: rds:DescribeDBClusters"
		gum log --level info "Run 'aws rds describe-db-clusters' to verify access"
		exit 1
	fi

	# Extract connection details (writer endpoint)
	local endpoint port engine username iam_enabled
	endpoint=$(echo "$cluster_info" | jq -r '.DBClusters[0].Endpoint')
	port=$(echo "$cluster_info" | jq -r '.DBClusters[0].Port')
	engine=$(echo "$cluster_info" | jq -r '.DBClusters[0].Engine')
	username=$(echo "$cluster_info" | jq -r '.DBClusters[0].MasterUsername')
	iam_enabled=$(echo "$cluster_info" | jq -r '.DBClusters[0].IAMDatabaseAuthenticationEnabled')

	# Check for valid endpoint
	if [ -z "$endpoint" ] || [ "$endpoint" = "null" ]; then
		gum log --level error "Cluster endpoint not available"
		gum log --level info "The cluster may not be ready or in 'available' state"
		gum log --level info "Check cluster status with: aws rds describe-db-clusters --db-cluster-identifier $cluster"
		exit 1
	fi

	# Check for PostgreSQL engine
	if [[ ! "$engine" =~ ^(aurora-postgresql) ]]; then
		gum log --level error "Only Aurora PostgreSQL clusters are supported for IAM authentication"
		gum log --level info "Current engine: $engine"
		gum log --level info "Supported engines: aurora-postgresql"
		exit 1
	fi

	# Check if IAM auth is enabled
	if [ "$iam_enabled" != "true" ]; then
		gum log --level error "IAM database authentication is not enabled for this cluster"
		gum log --level info "To enable IAM authentication:"
		gum log --level info "1. Modify the DB cluster in RDS console"
		gum log --level info "2. Enable 'Password and IAM database authentication'"
		gum log --level info "3. Apply changes (may require cluster restart)"
		exit 1
	fi

	# Check if psql is installed
	if ! command -v psql >/dev/null 2>&1; then
		gum log --level error "psql client not found"
		gum log --level info "Install PostgreSQL client:"
		gum log --level info "macOS: brew install postgresql"
		gum log --level info "Ubuntu/Debian: apt-get install postgresql-client"
		gum log --level info "Amazon Linux: yum install postgresql"
		exit 1
	fi

	# Generate IAM auth token
	local region
	region=$(_get_aws_region)

	local token
	token=$(
		gum spin --title "Generating IAM Auth Token..." -- \
			aws rds generate-db-auth-token \
			--hostname "$endpoint" \
			--port "$port" \
			--username "$username" \
			--region "$region" 2>&1
	)

	# shellcheck disable=SC2181
	if [ $? -ne 0 ]; then
		gum log --level error "Failed to generate IAM auth token"
		gum log --level info "Check your AWS credentials and IAM permissions"
		gum log --level info "Required IAM permissions: rds-db:connect"
		gum log --level info "IAM policy resource: arn:aws:rds-db:${region}:*:dbuser:*/${username}"
		gum log --level info "Run 'aws sts get-caller-identity' to verify your identity"
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

# _copy_instance_arn()
#
# Copy DB instance ARN to clipboard
#
# PARAMETERS:
#   $1 - DB instance identifier (required)
#
# DESCRIPTION:
#   Fetches the instance ARN and copies it to the clipboard
#
_copy_instance_arn() {
	local instance="${1:-}"

	if [ -z "$instance" ]; then
		gum log --level error "DB instance identifier is required"
		exit 1
	fi

	local arn
	arn=$(
		gum spin --title "Getting AWS RDS Instance ARN..." -- \
			aws rds describe-db-instances --db-instance-identifier "$instance" --query 'DBInstances[0].DBInstanceArn' --output text 2>/dev/null
	)

	if [ -z "$arn" ] || [ "$arn" = "None" ]; then
		gum log --level error "Failed to fetch instance ARN"
		exit 1
	fi

	_copy_to_clipboard "$arn" "instance ARN"
}

# _copy_instance_name()
#
# Copy DB instance identifier to clipboard
#
# PARAMETERS:
#   $1 - DB instance identifier (required)
#
# DESCRIPTION:
#   Copies the instance identifier to the clipboard
#
_copy_instance_name() {
	local instance="${1:-}"

	if [ -z "$instance" ]; then
		gum log --level error "DB instance identifier is required"
		exit 1
	fi

	_copy_to_clipboard "$instance" "instance identifier"
}

# _copy_cluster_arn()
#
# Copy DB cluster ARN to clipboard
#
# PARAMETERS:
#   $1 - DB cluster identifier (required)
#
# DESCRIPTION:
#   Fetches the cluster ARN and copies it to the clipboard
#
_copy_cluster_arn() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "DB cluster identifier is required"
		exit 1
	fi

	local arn
	arn=$(
		gum spin --title "Getting AWS RDS Cluster ARN..." -- \
			aws rds describe-db-clusters --db-cluster-identifier "$cluster" --query 'DBClusters[0].DBClusterArn' --output text 2>/dev/null
	)

	if [ -z "$arn" ] || [ "$arn" = "None" ]; then
		gum log --level error "Failed to fetch cluster ARN"
		exit 1
	fi

	_copy_to_clipboard "$arn" "cluster ARN"
}

# _copy_cluster_name()
#
# Copy DB cluster identifier to clipboard
#
# PARAMETERS:
#   $1 - DB cluster identifier (required)
#
# DESCRIPTION:
#   Copies the cluster identifier to the clipboard
#
_copy_cluster_name() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "DB cluster identifier is required"
		exit 1
	fi

	_copy_to_clipboard "$cluster" "cluster identifier"
}

# _aws_rds_instance_help_interactive()
#
# Display interactive help for RDS instance commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_rds_instance_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open in console |
| **`alt-c`** | Connect (psql) |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy identifier |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_rds_cluster_help_interactive()
#
# Display interactive help for RDS cluster commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_rds_cluster_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open in console |
| **`alt-c`** | Connect (psql) |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy identifier |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_rds_instance_list_cmd()
#
# Fetch and format RDS instances for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list RDS instances and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_rds_instance_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local instance_list_jq='(["ID", "ENGINE", "STATUS", "CLASS"] | @tsv),
	                        (.DBInstances[] | [.DBInstanceIdentifier, .Engine, .DBInstanceStatus, .DBInstanceClass] | @tsv)'

	# Fetch and format RDS instances (without gum spin - caller handles that)
	aws rds describe-db-instances "${list_args[@]}" --output json |
		jq -r "$instance_list_jq" | column -t -s $'\t'
}

# _aws_rds_cluster_list_cmd()
#
# Fetch and format RDS clusters for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list RDS clusters and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_rds_cluster_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local cluster_list_jq='(["ID", "ENGINE", "STATUS", "MEMBERS"] | @tsv),
	                       (.DBClusters[] | [.DBClusterIdentifier, .Engine, .Status, (.DBClusterMembers | length)] | @tsv)'

	# Fetch and format RDS clusters (without gum spin - caller handles that)
	aws rds describe-db-clusters "${list_args[@]}" --output json |
		jq -r "$cluster_list_jq" | column -t -s $'\t'
}

# Command router
case "${1:-}" in
list-instances)
	shift
	_aws_rds_instance_list_cmd "$@"
	;;
list-clusters)
	shift
	_aws_rds_cluster_list_cmd "$@"
	;;
help-instances)
	_aws_rds_instance_help_interactive
	;;
help-clusters)
	_aws_rds_cluster_help_interactive
	;;
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
copy-instance-arn)
	shift
	_copy_instance_arn "$@"
	;;
copy-instance-name)
	shift
	_copy_instance_name "$@"
	;;
copy-cluster-arn)
	shift
	_copy_cluster_arn "$@"
	;;
copy-cluster-name)
	shift
	_copy_cluster_name "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_rds_cmd - Utility commands for RDS operations

LISTING:
    aws_rds_cmd list-instances [aws-cli-args]
    aws_rds_cmd list-clusters [aws-cli-args]

CONSOLE VIEWS:
    aws_rds_cmd view-instance <db-instance-identifier>
    aws_rds_cmd view-cluster <db-cluster-identifier>

DATABASE CONNECTION:
    aws_rds_cmd connect-instance <db-instance-identifier>
    aws_rds_cmd connect-cluster <db-cluster-identifier>

CLIPBOARD OPERATIONS:
    aws_rds_cmd copy-instance-arn <db-instance-identifier>
    aws_rds_cmd copy-instance-name <db-instance-identifier>
    aws_rds_cmd copy-cluster-arn <db-cluster-identifier>
    aws_rds_cmd copy-cluster-name <db-cluster-identifier>

DESCRIPTION:
    list-instances/list-clusters: Fetches and formats RDS resources for fzf display.
    View commands open RDS resources in the AWS Console via the default browser.
    Connection commands use psql with IAM authentication (PostgreSQL only).
    Clipboard operations copy resource identifiers to the system clipboard.

EXAMPLES:
    # List resources (for fzf reload)
    aws_rds_cmd list-instances --region us-east-1
    aws_rds_cmd list-clusters

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
	gum log --level info "Usage: aws_rds_cmd {list-*|view-*|connect-*|copy-*} [args]"
	gum log --level info "Run 'aws_rds_cmd --help' for more information"
	exit 1
	;;
esac
