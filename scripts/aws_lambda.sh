#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

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
	local exit_code=0
	# Call the _cmd script to fetch and format functions
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	function_list="$(
		gum spin --title "Loading AWS Lambda Functions..." -- \
			"$_aws_lambda_source_dir/aws_lambda_cmd.sh" list "${list_functions_args[@]}"
	)" || exit_code=$?

	if [ $exit_code -ne 0 ]; then
		gum log --level error "Failed to list Lambda functions (exit code: $exit_code)"
		gum log --level info "Check your AWS credentials and permissions"
		return 1
	fi

	# Check if any functions were found
	if [ -z "$function_list" ]; then
		gum log --level warn "No Lambda functions found"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Build fzf options with user-provided flags
	_aws_fzf_options "LAMBDA"

	# Display in fzf with keybindings
	echo "$function_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon Lambda Functions $_fzf_split $aws_context" \
		--preview "$_aws_lambda_source_dir/aws_lambda_cmd.sh help" \
		--bind "ctrl-r:reload($_aws_lambda_source_dir/aws_lambda_cmd.sh list ${list_functions_args[*]})" \
		--bind "enter:execute(aws lambda get-function --function-name {1} | jq . | gum pager)" \
		--bind "ctrl-o:execute-silent($_aws_lambda_source_dir/aws_lambda_cmd.sh view-function {1})" \
		--bind "alt-t:execute($_aws_lambda_source_dir/aws_log_cmd.sh tail-log /aws/lambda/{1})+abort" \
		--bind "alt-l:execute($_aws_lambda_source_dir/aws_log_cmd.sh read-log /aws/lambda/{1})+abort" \
		--bind "alt-a:execute-silent($_aws_lambda_source_dir/aws_lambda_cmd.sh copy-arn {1})" \
		--bind "alt-n:execute-silent($_aws_lambda_source_dir/aws_lambda_cmd.sh copy-name {1})" \
		--bind "alt-h:toggle-preview"
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
    All resources:
        ctrl-r      Reload the list
        enter       Show function details (configuration, code, etc.)
        ctrl-o      Open function in AWS Console
        alt-t       Tail function logs from CloudWatch
        alt-a       Copy function ARN to clipboard
        alt-n       Copy function name to clipboard

PERFORMANCE:
    The list-functions API paginates results automatically.
    Use --max-items to control the total number of functions returned.
    Each page fetches up to 50 functions. For accounts with many functions,
    consider using AWS CLI filters or querying specific regions.

LOG TAILING:
    Press alt-t to tail CloudWatch logs for the selected function.
    Logs are streamed from /aws/lambda/<function-name> log group.


EXAMPLES:
    # List all Lambda functions
    aws fzf lambda list

    # List functions in specific region
    aws fzf lambda list --region us-west-2

    # Use with specific profile
    aws fzf lambda list --profile production

    # Limit total functions returned
    aws fzf lambda list --max-items 100

    # Combine region and profile
    aws fzf lambda list --region eu-west-1 --profile prod

SEE ALSO:
    AWS CLI Lambda: https://docs.aws.amazon.com/cli/latest/reference/lambda/
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
