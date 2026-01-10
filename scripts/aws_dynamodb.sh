#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

_aws_dynamodb_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_dynamodb_source_dir/aws_core.sh"

# _aws_dynamodb_table_list()
#
# Interactive fuzzy finder for DynamoDB tables
#
# DESCRIPTION:
#   Displays a list of DynamoDB tables in an interactive fzf interface.
#   Users can view details or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_dynamodb_table_list() {
	local list_tables_args=("$@")

	local table_list
	# Call the _cmd script to fetch and format tables
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	table_list="$(
		gum spin --title "Loading AWS DynamoDB Tables..." -- \
			"$_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh" list "${list_tables_args[@]}"
	)"

	# Check if any tables were found
	if [ -z "$table_list" ]; then
		gum log --level warn "No DynamoDB tables found"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Build fzf options with user-provided flags
	_aws_fzf_options

	# Display in fzf with keybindings
	echo "$table_list" | fzf "${_fzf_options[@]}" \
		--with-nth=1.. --accept-nth 1 \
		--footer "$_fzf_icon DynamoDB Tables $_fzf_split $aws_context" \
		--bind "ctrl-r:reload($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh list ${list_tables_args[*]})" \
		--bind "ctrl-o:execute-silent($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh view-table {1})" \
		--bind "ctrl-O:execute-silent($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh view-items {1})" \
		--bind "enter:execute(aws dynamodb describe-table --table-name {1} | jq .)+abort" \
		--bind "alt-a:execute-silent($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh copy-arn {1})" \
		--bind "alt-n:execute-silent($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh copy-name {1})"
}

# _aws_dynamodb_help()
#
# Show DynamoDB command help
#
_aws_dynamodb_help() {
	cat <<'EOF'
aws fzf dynamodb - Interactive DynamoDB table browser

USAGE:
    aws fzf dynamodb table list [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile

KEYBOARD SHORTCUTS:
    All resources:
        ctrl-r      Reload the list
        enter       View table details (full JSON)
        ctrl-o      Open table in AWS Console (overview)
        ctrl-O      Open items explorer in AWS Console
        alt-a       Copy table ARN to clipboard
        alt-n       Copy table name to clipboard

PERFORMANCE:
    Table listing is optimized for speed - only table names are fetched initially.
    The list-tables API paginates results automatically (up to 100 per page).
    Full table details (schema, indexes, capacity) are fetched on-demand when
    you press enter on a specific table.

    For accounts with many tables, consider querying specific regions to reduce
    the list size, as DynamoDB tables are region-specific.

CONSOLE INTEGRATION:
    Press ctrl-o to open table overview (shows schema, indexes, metrics, settings).
    Press alt-enter to open items explorer for browsing/querying table data.
    DynamoDB is a managed NoSQL service - no direct client connection like psql.

EXAMPLES:
    # List all DynamoDB tables
    aws fzf dynamodb table list

    # List tables in specific region
    aws fzf dynamodb table list --region us-west-2

    # Use with specific profile
    aws fzf dynamodb table list --profile production

    # Combine region and profile
    aws fzf dynamodb table list --region ap-southeast-1 --profile prod

SEE ALSO:
    AWS CLI DynamoDB: https://docs.aws.amazon.com/cli/latest/reference/dynamodb/
    Amazon DynamoDB Guide: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/
EOF
}

# aws_dynamodb.sh - DynamoDB table browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# DynamoDB table listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from aws_core.sh

# _aws_dynamodb_main()
#
# Handle dynamodb resource and action routing
#
# DESCRIPTION:
#   Routes dynamodb commands using nested resource → action structure.
#   Supports table resource with list action.
#
# PARAMETERS:
#   $1 - Resource (table)
#   $2 - Action (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown resource/action or error
#
_aws_dynamodb_main() {
	local resource="$1"
	shift

	case $resource in
	table)
		local action="$1"
		shift
		case $action in
		list)
			_aws_dynamodb_table_list "$@"
			;;
		--help | -h | help | "")
			_aws_dynamodb_help
			;;
		*)
			gum log --level error "Unknown table action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf dynamodb --help' for usage"
			return 1
			;;
		esac
		;;
	--help | -h | help | "")
		_aws_dynamodb_help
		;;
	*)
		gum log --level error "Unknown dynamodb resource '$resource'"
		gum log --level info "Supported: table"
		gum log --level info "Run 'aws fzf dynamodb --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_dynamodb_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_dynamodb_main "$@"
fi
