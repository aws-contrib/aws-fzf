#!/usr/bin/env bash

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

set -euo pipefail

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

# Command router
case "${1:-}" in
view-function)
	shift
	_aws_lambda_view_function "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_lambda_cmd - Utility commands for Lambda operations

OPERATIONS:
    aws_lambda_cmd view-function <function-name>

DESCRIPTION:
    Utility commands for Lambda operations.
    view-function opens Lambda functions in the AWS Console.

EXAMPLES:
    # Open in console
    aws_lambda_cmd view-function my-function

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_lambda_cmd {view-function} [args]"
	gum log --level info "Run 'aws_lambda_cmd --help' for more information"
	exit 1
	;;
esac
