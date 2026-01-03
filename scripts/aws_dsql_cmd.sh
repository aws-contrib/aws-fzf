#!/usr/bin/env bash

# aws_dsql_cmd - Utility helper for DSQL operations
#
# This executable handles DSQL console viewing and connections.
# Designed to be called from fzf keybindings and other scripts.
#
# USAGE:
#   aws_dsql_cmd view-cluster <cluster-identifier>
#   aws_dsql_cmd connect-cluster <cluster-identifier>
#
# DESCRIPTION:
#   Provides console viewing and psql connection functionality for DSQL clusters.

set -euo pipefail

# Source shared core utilities
_aws_dsql_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_dsql_cmd_source_dir/aws_core.sh"

# _aws_dsql_view_cluster()
#
# Open DSQL cluster in AWS Console
#
# PARAMETERS:
#   $1 - Cluster identifier (required)
#
# DESCRIPTION:
#   Opens the specified DSQL cluster in the default web browser
#   via the AWS Console URL
#
_aws_dsql_view_cluster() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster identifier is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/dsql/clusters/${cluster}/home"
}

# _aws_dsql_connect_cluster()
#
# Connect to DSQL cluster using psql with IAM authentication
#
# PARAMETERS:
#   $1 - Cluster identifier (required)
#
# DESCRIPTION:
#   Connects to a DSQL cluster using psql client with IAM auth token.
#   DSQL always uses IAM authentication and is PostgreSQL-compatible.
#
_aws_dsql_connect_cluster() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster identifier is required"
		exit 1
	fi

	local cluster_info
	# Get cluster details
	cluster_info="$(
		gum spin --title "Fetching AWS DSQL Cluster details..." -- \
			aws dsql get-cluster \
			--identifier "$cluster" \
			--output json
	)"

	if [ $? -ne 0 ]; then
		gum log --level error "Failed to describe cluster: $cluster"
		exit 1
	fi

	# Extract endpoint
	local endpoint
	endpoint=$(echo "$cluster_info" | jq -r '.endpoint')

	# Check if psql is installed
	if ! command -v psql >/dev/null 2>&1; then
		gum log --level error "psql client not found"
		gum log --level info "Install PostgreSQL client: brew install postgresql"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	local token
	token=$(
		gum spin --title "Generating IAM auth token..." -- \
			aws dsql generate-db-connect-admin-auth-token \
			--region "$region" \
			--expires-in 3600 \
			--hostname "$endpoint"
	)

	if [ $? -ne 0 ]; then
		gum log --level error "Failed to generate auth token"
		exit 1
	fi

	export PGHOST="$endpoint"
	export PGPORT="5432"
	export PGUSER="admin"
	export PGPASSWORD="$token"
	export PGSSLMODE="require"

	gum log --level info "Connecting to AWS DSQL Cluster $cluster ($endpoint:5432) as admin..."
	# Connect to database
	psql -d postgres
}

# Command router
case "${1:-}" in
view-cluster)
	shift
	_aws_dsql_view_cluster "$@"
	;;
connect-cluster)
	shift
	_aws_dsql_connect_cluster "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_dsql_cmd - Utility commands for DSQL operations

CONSOLE VIEWS:
    aws_dsql_cmd view-cluster <cluster-identifier>

DATABASE CONNECTION:
    aws_dsql_cmd connect-cluster <cluster-identifier>

DESCRIPTION:
    View commands open DSQL resources in the AWS Console via the default browser.
    Connection commands use psql with IAM authentication.

EXAMPLES:
    # Console views
    aws_dsql_cmd view-cluster my-dsql-cluster

    # Database connections
    aws_dsql_cmd connect-cluster my-dsql-cluster

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_dsql_cmd {view-*|connect-*} [args]"
	gum log --level info "Run 'aws_dsql_cmd --help' for more information"
	exit 1
	;;
esac
