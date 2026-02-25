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
	) || true

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

# _aws_lambda_help_interactive()
#
# Display interactive help for Lambda commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_lambda_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open in console |
| **`alt-t`** | Tail logs |
| **`alt-l`** | View logs |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_lambda_list_cmd()
#
# Fetch and format Lambda functions for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, --max-items, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list Lambda functions and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_lambda_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local function_list_jq='(["NAME", "RUNTIME", "MODIFIED"] | @tsv),
	                        (.Functions[] | [.FunctionName, (.Runtime // "none"), (.LastModified[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch and format Lambda functions (without gum spin - caller handles that)
	aws lambda list-functions "${list_args[@]}" --output json |
		jq -r "$function_list_jq" | column -t -s $'\t'
}

# Command router
case "${1:-}" in
list)
	shift
	_aws_lambda_list_cmd "$@"
	;;
help)
	_aws_lambda_help_interactive
	;;
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
--help | -h | help | "")
	cat <<'EOF'
aws_lambda_cmd - Utility commands for Lambda operations

LISTING:
    aws_lambda_cmd list [aws-cli-args]

CONSOLE VIEWS:
    aws_lambda_cmd view-function <function-name>

CLIPBOARD OPERATIONS:
    aws_lambda_cmd copy-arn <function-name>
    aws_lambda_cmd copy-name <function-name>

DESCRIPTION:
    Utility commands for Lambda operations.
    list fetches and formats Lambda functions for fzf display.
    view-function opens Lambda functions in the AWS Console.
    copy-arn copies the function ARN to clipboard.
    copy-name copies the function name to clipboard.

EXAMPLES:
    # List functions (for fzf reload)
    aws_lambda_cmd list --region us-east-1

    # Console view
    aws_lambda_cmd view-function my-function

    # Clipboard operations
    aws_lambda_cmd copy-arn my-function
    aws_lambda_cmd copy-name my-function

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_lambda_cmd {list|view-function|copy-arn|copy-name} [args]"
	gum log --level info "Run 'aws_lambda_cmd --help' for more information"
	exit 1
	;;
esac
