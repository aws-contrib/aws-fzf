#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

# aws_lambda_cmd - Utility helper for Lambda operations
#
# This executable handles Lambda operations.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_lambda_cmd view-function <function-name>
#
# DESCRIPTION:
#   Performs Lambda operations including opening functions in the AWS Console.

# Source shared core utilities
_aws_lambda_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_lambda_cmd_source_dir/aws_core.sh"

# _aws_lambda_view_function()
#
# Open Lambda function in AWS Console
#
# PARAMETERS:
#   $1 - Function name (required)
#
# DESCRIPTION:
#   Opens the specified Lambda function in the default web browser
#   via the AWS Console URL
#
_aws_lambda_view_function() {
	local function_name="${1:-}"

	if [ -z "$function_name" ]; then
		gum log --level error "Function name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	# Construct Lambda console URL
	# Format: https://<region>.console.aws.amazon.com/lambda/home?region=<region>#/functions/<function-name>
	_open_url "https://${region}.console.aws.amazon.com/lambda/home?region=${region}#/functions/${function_name}"
}

# _aws_lambda_copy_arn()
#
# Copy function ARN to clipboard
#
# PARAMETERS:
#   $1 - Function name (required)
#
# DESCRIPTION:
#   Fetches the function ARN and copies it to the clipboard
#
_aws_lambda_copy_arn() {
	local function="${1:-}"

	if [ -z "$function" ]; then
		gum log --level error "Function name is required"
		exit 1
	fi

	local arn
	arn=$(
		gum spin --title "Getting AWS Lambda Function ARN..." -- \
			aws lambda get-function --function-name "$function" --query 'Configuration.FunctionArn' --output text 2>/dev/null
	)

	if [ -z "$arn" ]; then
		gum log --level error "Failed to fetch function ARN"
		exit 1
	fi

	_copy_to_clipboard "$arn" "function ARN"
}

# _aws_lambda_copy_name()
#
# Copy function name to clipboard
#
# PARAMETERS:
#   $1 - Function name (required)
#
# DESCRIPTION:
#   Copies the function name to the clipboard
#
_aws_lambda_copy_name() {
	local function="${1:-}"

	if [ -z "$function" ]; then
		gum log --level error "Function name is required"
		exit 1
	fi

	_copy_to_clipboard "$function" "function name"
}

# _aws_lambda_tail_logs()
#
# Tail Lambda function logs
#
# PARAMETERS:
#   $1 - Function name (required)
#
# DESCRIPTION:
#   Tails logs for the Lambda function from CloudWatch Logs.
#   Lambda functions have log groups named /aws/lambda/<function-name>
#
_aws_lambda_tail_logs() {
	local function="${1:-}"

	if [ -z "$function" ]; then
		gum log --level error "Function name is required"
		exit 1
	fi

	local log_group="/aws/lambda/${function}"

	aws logs tail "$log_group" --follow --format short
}

# Command router
case "${1:-}" in
view-function)
	shift
	_aws_lambda_view_function "$@"
	;;
copy-arn)
	shift
	_aws_lambda_copy_arn "$@"
	;;
copy-name)
	shift
	_aws_lambda_copy_name "$@"
	;;
tail-logs)
	shift
	_aws_lambda_tail_logs "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_lambda_cmd - Utility commands for Lambda operations

CONSOLE VIEWS:
    aws_lambda_cmd view-function <function-name>

CLIPBOARD OPERATIONS:
    aws_lambda_cmd copy-arn <function-name>
    aws_lambda_cmd copy-name <function-name>

LOG OPERATIONS:
    aws_lambda_cmd tail-logs <function-name>

DESCRIPTION:
    Utility commands for Lambda operations.
    view-function opens Lambda functions in the AWS Console.
    copy-arn copies the function ARN to clipboard.
    copy-name copies the function name to clipboard.
    tail-logs tails the function's CloudWatch Logs.

EXAMPLES:
    # Console view
    aws_lambda_cmd view-function my-function

    # Clipboard operations
    aws_lambda_cmd copy-arn my-function
    aws_lambda_cmd copy-name my-function

    # Tail logs
    aws_lambda_cmd tail-logs my-function

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_lambda_cmd {view-function} [args]"
	gum log --level info "Run 'aws_lambda_cmd --help' for more information"
	exit 1
	;;
esac
