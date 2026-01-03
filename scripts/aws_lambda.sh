#!/bin/bash
set -o pipefail

_aws_lambda_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_lambda_source_dir/aws_core.sh"

# _aws_lambda_list()
#
# Interactive fuzzy finder for Lambda functions
#
# DESCRIPTION:
#   Displays a list of Lambda functions in an interactive fzf interface.
#   Users can view details or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_lambda_list() {
	local list_functions_args=("$@")

	local function_list
	# Define jq formatting
	local function_list_jq='(["NAME", "RUNTIME", "MODIFIED"] | @tsv),
	                        (.Functions[] | [.FunctionName, (.Runtime // "none"), (.LastModified[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch functions
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	function_list="$(
		gum spin --title "Loading AWS Lambda Functions..." -- \
			aws lambda list-functions $list_functions_args --output json |
			jq -r "$function_list_jq" | column -t -s $'\t'
	)"

	# Check if any functions were found
	if [ -z "$function_list" ]; then
		gum log --level warn "No Lambda functions found"
		return 1
	fi

	# Display in fzf with keybindings
	echo "$function_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon Lambda Functions" \
		--bind "enter:execute(aws lambda get-function --function-name {1} | jq .)+abort" \
		--bind "ctrl-o:execute-silent($_aws_lambda_source_dir/aws_lambda_cmd.sh view-function {1})"
}

# _aws_lambda_help()
#
# Show lambda command help
#
_aws_lambda_help() {
	cat <<'EOF'
aws fzf lambda - Interactive Lambda browser

USAGE:
    aws fzf lambda list [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile
    --max-items <number>        Maximum functions to fetch
    --function-version <ALL|version>  Function version to list

KEYBOARD SHORTCUTS:
    enter       Show function details (configuration, code, etc.)
    ctrl-o      Open function in AWS Console

EXAMPLES:
    aws fzf lambda list
    aws fzf lambda list --region us-west-2
    aws fzf lambda list --profile production
    aws fzf lambda list --max-items 100
EOF
}

# aws_lambda.sh - Lambda browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# Lambda function listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum

# _aws_lambda_main()
#
# Handle lambda subcommands
#
# DESCRIPTION:
#   Routes lambda subcommands to appropriate handlers. Supports
#   list for interactive Lambda function browsing.
#
# PARAMETERS:
#   $1 - Subcommand (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown subcommand or error
#
_aws_lambda_main() {
	local subcommand="$1"
	shift

	case $subcommand in
	list)
		_aws_lambda_list "$@"
		;;
	--help | -h | help | "")
		_aws_lambda_help
		;;
	*)
		gum log --level error "Unknown lambda subcommand '$subcommand'"
		gum log --level info "Supported: list"
		gum log --level info "Run 'aws fzf lambda --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_lambda_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_lambda_main "$@"
fi
