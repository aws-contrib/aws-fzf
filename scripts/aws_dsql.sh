#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

_aws_dsql_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_dsql_source_dir/aws_core.sh"

# _aws_dsql_cluster_list()
#
# Interactive fuzzy finder for DSQL clusters
#
# DESCRIPTION:
#   Displays a list of DSQL clusters in an interactive fzf interface.
#   Users can view details, open the AWS Console, or connect with psql.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_dsql_cluster_list() {
	local list_clusters_args=("$@")

	local cluster_list
	# Define jq formatting based on actual JSON structure
	# list-clusters only returns identifier and arn (no status/endpoint)
	local cluster_list_jq='(["IDENTIFIER", "ARN"] | @tsv),
	                       (.clusters[] | [.identifier, .arn] | @tsv)'

	# Fetch DSQL clusters
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	cluster_list="$(
		gum spin --title "Loading AWS DSQL Clusters..." -- \
			aws dsql list-clusters "${list_clusters_args[@]}" --output json |
			jq -r "$cluster_list_jq" | column -t -s $'\t'
	)"

	# Check if any clusters were found
	if [ -z "$cluster_list" ]; then
		gum log --level warn "No DSQL clusters found"
		return 1
	fi

	# Display in fzf with full keybindings
	echo "$cluster_list" | fzf "${_fzf_options[@]}" \
		--with-nth=1.. --accept-nth 1 \
		--footer "$_fzf_icon DSQL Clusters" \
		--bind "ctrl-o:execute-silent($_aws_dsql_source_dir/aws_dsql_cmd.sh view-cluster {1})" \
		--bind "enter:execute(aws dsql get-cluster --identifier {1} | jq .)+abort" \
		--bind "alt-c:become($_aws_dsql_source_dir/aws_dsql_cmd.sh connect-cluster {1})" \
		--bind "alt-a:execute-silent($_aws_dsql_source_dir/aws_dsql_cmd.sh copy-cluster-arn {1})" \
		--bind "alt-n:execute-silent($_aws_dsql_source_dir/aws_dsql_cmd.sh copy-cluster-name {1})"
}

# _aws_dsql_help()
#
# Show DSQL command help
#
_aws_dsql_help() {
	cat <<'EOF'
aws fzf dsql - Interactive DSQL cluster browser

USAGE:
    aws fzf dsql cluster list [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile

KEYBOARD SHORTCUTS:
    All resources:
        ctrl-o      Open cluster in AWS Console
        enter       View cluster details (full JSON)
        alt-c       Connect to cluster with psql (IAM auth)
        alt-a       Copy cluster ARN to clipboard
        alt-n       Copy cluster identifier to clipboard

SECURITY:
    DSQL cluster connections (alt-c) require:
    - IAM policy allowing dsql:DbConnect action on the cluster
    - psql client installed (brew install postgresql)

    DSQL always uses IAM authentication (no password required).
    IAM auth tokens are valid for 1 hour and provide secure, temporary access.
    Default username is 'admin' with full database permissions.
    Use caution when connecting to production clusters.

PERFORMANCE:
    The list-clusters API paginates results automatically.
    DSQL is optimized for serverless PostgreSQL workloads.
    Clusters are always available - no instance management required.

EXAMPLES:
    # List all DSQL clusters
    aws fzf dsql cluster list

    # List clusters in specific region
    aws fzf dsql cluster list --region us-west-2

    # Use with specific profile
    aws fzf dsql cluster list --profile production

    # Combine region and profile
    aws fzf dsql cluster list --region us-east-1 --profile prod

SEE ALSO:
    AWS CLI DSQL: https://docs.aws.amazon.com/cli/latest/reference/dsql/
    Amazon Aurora DSQL: https://docs.aws.amazon.com/aurora-dsql/
EOF
}

# aws_dsql.sh - DSQL cluster browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# DSQL cluster listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from aws_core.sh

# _aws_dsql_main()
#
# Handle dsql resource and action routing
#
# DESCRIPTION:
#   Routes dsql commands using nested resource → action structure.
#   Supports cluster resource with list action.
#
# PARAMETERS:
#   $1 - Resource (cluster)
#   $2 - Action (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown resource/action or error
#
_aws_dsql_main() {
	local resource="$1"
	shift

	case $resource in
	cluster)
		local action="$1"
		shift
		case $action in
		list)
			_aws_dsql_cluster_list "$@"
			;;
		--help | -h | help | "")
			_aws_dsql_help
			;;
		*)
			gum log --level error "Unknown cluster action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf dsql --help' for usage"
			return 1
			;;
		esac
		;;
	--help | -h | help | "")
		_aws_dsql_help
		;;
	*)
		gum log --level error "Unknown dsql resource '$resource'"
		gum log --level info "Supported: cluster"
		gum log --level info "Run 'aws fzf dsql --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_dsql_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_dsql_main "$@"
fi
