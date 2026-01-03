#!/bin/bash
set -o pipefail

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
	# Define jq formatting
	# list-tables returns simple array of table names
	local table_list_jq='(["TABLE NAME"] | @tsv),
	                     (.TableNames[] | [.] | @tsv)'

	# Fetch DynamoDB tables
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	table_list="$(
		gum spin --title "Loading AWS DynamoDB Tables..." -- \
			aws dynamodb list-tables $list_tables_args --output json |
			jq -r "$table_list_jq" | column -t -s $'\t'
	)"

	# Check if any tables were found
	if [ -z "$table_list" ]; then
		gum log --level warn "No DynamoDB tables found"
		return 1
	fi

	# Display in fzf with keybindings
	echo "$table_list" | fzf "${_fzf_options[@]}" \
		--with-nth=1.. --accept-nth 1 \
		--footer "$_fzf_icon DynamoDB Tables" \
		--bind "ctrl-o:execute-silent($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh view-table {1})" \
		--bind "enter:execute(aws dynamodb describe-table --table-name {1} | jq .)+abort" \
		--bind "alt-enter:execute-silent($_aws_dynamodb_source_dir/aws_dynamodb_cmd.sh view-items {1})"
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
        ctrl-o      Open table in AWS Console (overview)
        enter       View table details (full JSON)
        alt-enter   Open items explorer in AWS Console

EXAMPLES:
    # List DynamoDB tables
    aws fzf dynamodb table list
    aws fzf dynamodb table list --region us-west-2
    aws fzf dynamodb table list --profile production
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
