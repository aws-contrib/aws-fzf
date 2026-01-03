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
		gum log --level info "Check that the cluster exists and you have permissions"
		gum log --level info "Required IAM permissions: dsql:GetCluster"
		gum log --level info "Run 'aws dsql list-clusters' to see available clusters"
		exit 1
	fi

	# Extract endpoint
	local endpoint
	endpoint=$(echo "$cluster_info" | jq -r '.endpoint')

	if [ -z "$endpoint" ] || [ "$endpoint" = "null" ]; then
		gum log --level error "Cluster endpoint not found for: $cluster"
		gum log --level info "The cluster may not be ready or may not exist"
		exit 1
	fi

	# Check if psql is installed
	if ! command -v psql >/dev/null 2>&1; then
		gum log --level error "psql client not found"
		gum log --level info "Install PostgreSQL client: brew install postgresql"
		gum log --level info "macOS: brew install postgresql"
		gum log --level info "Ubuntu/Debian: apt-get install postgresql-client"
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
		gum log --level error "Failed to generate IAM auth token"
		gum log --level info "Check your AWS credentials and IAM permissions"
		gum log --level info "Required IAM permissions: dsql:DbConnect"
		gum log --level info "IAM policy resource: arn:aws:dsql:${region}:*:cluster/${cluster}"
		gum log --level info "Run 'aws sts get-caller-identity' to verify your identity"
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

# _copy_cluster_arn()
#
# Copy DSQL cluster ARN to clipboard
#
# PARAMETERS:
#   $1 - Cluster identifier (required)
#
# DESCRIPTION:
#   Fetches the cluster ARN and copies it to the clipboard
#
_copy_cluster_arn() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster identifier is required"
		exit 1
	fi

	local arn
	arn=$(aws dsql get-cluster --identifier "$cluster" --query 'arn' --output text 2>/dev/null)

	if [ -z "$arn" ] || [ "$arn" = "None" ]; then
		gum log --level error "Failed to fetch cluster ARN"
		exit 1
	fi

	_copy_to_clipboard "$arn" "cluster ARN"
}

# _copy_cluster_name()
#
# Copy DSQL cluster identifier to clipboard
#
# PARAMETERS:
#   $1 - Cluster identifier (required)
#
# DESCRIPTION:
#   Copies the cluster identifier to the clipboard
#
_copy_cluster_name() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster identifier is required"
		exit 1
	fi

	_copy_to_clipboard "$cluster" "cluster identifier"
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
aws_dsql_cmd - Utility commands for DSQL operations

CONSOLE VIEWS:
    aws_dsql_cmd view-cluster <cluster-identifier>

DATABASE CONNECTION:
    aws_dsql_cmd connect-cluster <cluster-identifier>

CLIPBOARD OPERATIONS:
    aws_dsql_cmd copy-cluster-arn <cluster-identifier>
    aws_dsql_cmd copy-cluster-name <cluster-identifier>

DESCRIPTION:
    View commands open DSQL resources in the AWS Console via the default browser.
    Connection commands use psql with IAM authentication.
    Clipboard operations copy resource identifiers to the system clipboard.

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
