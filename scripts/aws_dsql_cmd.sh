#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

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
		gum spin --title "Getting AWS DSQL Cluster Details..." -- \
			aws dsql get-cluster \
			--identifier "$cluster" \
			--output json
	)" || true

	if [ -z "$cluster_info" ]; then
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
		gum spin --title "Generating IAM Auth Token..." -- \
			aws dsql generate-db-connect-admin-auth-token \
			--region "$region" \
			--expires-in "${FZF_AWS_DSQL_TOKEN_TTL:-3600}" \
			--hostname "$endpoint"
	) || true

	if [ -z "$token" ]; then
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

# _aws_dsql_copy_cluster_arn()
#
# Copy DSQL cluster ARN to clipboard
#
# PARAMETERS:
#   $1 - Cluster identifier (required)
#
# DESCRIPTION:
#   Fetches the cluster ARN and copies it to the clipboard
#
_aws_dsql_copy_cluster_arn() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster identifier is required"
		exit 1
	fi

	local arn
	arn=$(
		gum spin --title "Getting AWS DSQL Cluster ARN..." -- \
			aws dsql get-cluster --identifier "$cluster" --query 'arn' --output text 2>/dev/null
	) || true

	if [ -z "$arn" ] || [ "$arn" = "None" ]; then
		gum log --level error "Failed to fetch cluster ARN"
		exit 1
	fi

	_copy_to_clipboard "$arn" "cluster ARN"
}

# _aws_dsql_copy_cluster_name()
#
# Copy DSQL cluster identifier to clipboard
#
# PARAMETERS:
#   $1 - Cluster identifier (required)
#
# DESCRIPTION:
#   Copies the cluster identifier to the clipboard
#
_aws_dsql_copy_cluster_name() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster identifier is required"
		exit 1
	fi

	_copy_to_clipboard "$cluster" "cluster identifier"
}

# _aws_dsql_help_interactive()
#
# Display interactive help for DSQL commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_dsql_help_interactive() {
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
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_dsql_cluster_list_cmd()
#
# Fetch and format DSQL clusters for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list DSQL clusters and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_dsql_cluster_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local cluster_list_jq='(["IDENTIFIER", "ARN"] | @tsv),
	                       (.clusters[] | [.identifier, .arn] | @tsv)'

	# Fetch and format DSQL clusters (without gum spin - caller handles that)
	aws dsql list-clusters "${list_args[@]}" --output json |
		jq -r "$cluster_list_jq" | column -t -s $'\t'
}

# _aws_dsql_cmd_help()
#
# Display CLI help for DSQL commands
#
_aws_dsql_cmd_help() {
	cat <<'EOF'
aws fzf dsql - Utility commands for DSQL operations

LISTING:
    aws fzf dsql list [aws-cli-args]

CONSOLE VIEWS:
    aws fzf dsql view-cluster <cluster-identifier>

DATABASE CONNECTION:
    aws fzf dsql connect-cluster <cluster-identifier>

CLIPBOARD OPERATIONS:
    aws fzf dsql copy-cluster-arn <cluster-identifier>
    aws fzf dsql copy-cluster-name <cluster-identifier>

DESCRIPTION:
    list: Fetches and formats DSQL clusters for fzf display.
    View commands open DSQL resources in the AWS Console via the default browser.
    Connection commands use psql with IAM authentication.
    Clipboard operations copy resource identifiers to the system clipboard.

EXAMPLES:
    # List clusters (for fzf reload)
    aws fzf dsql list --region us-east-1

    # Console views
    aws fzf dsql view-cluster my-dsql-cluster

    # Database connections
    aws fzf dsql connect-cluster my-dsql-cluster

EOF
}

# Command router
case "${1:-}" in
list)
	shift
	_aws_dsql_cluster_list_cmd "$@"
	;;
help)
	_aws_dsql_help_interactive
	;;
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
	_aws_dsql_copy_cluster_arn "$@"
	;;
copy-cluster-name)
	shift
	_aws_dsql_copy_cluster_name "$@"
	;;
--help | -h | help | "")
	_aws_dsql_cmd_help
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws fzf dsql {list|view-*|connect-*|copy-*} [args]"
	gum log --level info "Run 'aws fzf dsql --help' for more information"
	exit 1
	;;
esac
