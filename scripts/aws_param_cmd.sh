#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

# aws_param_cmd - Utility helper for Parameter Store operations
#
# This executable handles Parameter Store operations.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_param_cmd get-value <parameter-name>
#   aws_param_cmd view-parameter <parameter-name>
#
# DESCRIPTION:
#   Performs Parameter Store operations including getting values
#   and opening parameters in the AWS Console.

# Source shared core utilities
_aws_param_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_param_cmd_source_dir/aws_core.sh"

# _aws_params_copy_value()
#
# Copy parameter value to clipboard
#
# PARAMETERS:
#   $1 - Parameter name (required)
#
# DESCRIPTION:
#   Retrieves a parameter value from Parameter Store and copies to clipboard.
#   More secure than displaying - value goes to clipboard, not terminal.
#
_aws_params_copy_value() {
	local param_name="${1:-}"

	if [ -z "$param_name" ]; then
		gum log --level error "Parameter name is required"
		exit 1
	fi

	# Get parameter type first
	local param_type
	param_type=$(
		gum spin --title "Getting AWS System Manager $param_name Parameter Type..." -- \
			aws ssm describe-parameters \
			--filters "Key=Name,Values=$param_name" \
			--query 'Parameters[0].Type' --output text
	)

	if [ -z "$param_type" ] || [ "$param_type" = "None" ]; then
		gum log --level error "Parameter not found: $param_name"
		exit 1
	fi

	# Get the value
	local param_value
	param_value=$(
		gum spin --title "Getting AWS System Manager $param_name Parameter Value..." -- \
			aws ssm get-parameter --name "$param_name" --with-decryption --query Parameter.Value --output text
	)

	if [ -z "$param_value" ]; then
		gum log --level error "Failed to retrieve parameter value"
		exit 1
	fi

	_copy_to_clipboard "$param_value" "parameter value"
}

# _aws_params_view_parameter()
#
# Open parameter in AWS Console
#
# PARAMETERS:
#   $1 - Parameter name (required)
#
# DESCRIPTION:
#   Opens the specified parameter in the default web browser
#   via the AWS Console URL
#
_aws_params_view_parameter() {
	local param_name="${1:-}"

	if [ -z "$param_name" ]; then
		gum log --level error "Parameter name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	# URL encode the parameter name
	local encoded_name
	encoded_name=$(printf '%s' "$param_name" | jq -sRr @uri)

	_open_url "https://console.aws.amazon.com/systems-manager/parameters/${encoded_name}/description?region=${region}"
}

# _aws_param_copy_arn()
#
# Copy parameter ARN to clipboard
#
# PARAMETERS:
#   $1 - Parameter name (required)
#
# DESCRIPTION:
#   Constructs the parameter ARN and copies it to the clipboard
#
_aws_param_copy_arn() {
	local param_name="${1:-}"

	if [ -z "$param_name" ]; then
		gum log --level error "Parameter name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	local account_id
	account_id=$(_get_aws_account_id)

	# Remove leading slash if present for ARN construction
	local param_path="${param_name#/}"
	local param_arn="arn:aws:ssm:${region}:${account_id}:parameter/${param_path}"
	_copy_to_clipboard "$param_arn" "parameter ARN"
}

# _aws_param_copy_name()
#
# Copy parameter name to clipboard
#
# PARAMETERS:
#   $1 - Parameter name (required)
#
# DESCRIPTION:
#   Copies the parameter name to the clipboard
#
_aws_param_copy_name() {
	local param="${1:-}"

	if [ -z "$param" ]; then
		gum log --level error "Parameter name is required"
		exit 1
	fi

	_copy_to_clipboard "$param" "parameter name"
}

# _aws_param_help_interactive()
#
# Display interactive help for parameter commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_param_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open in console |
| **`alt-v`** | Copy value |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_param_list_cmd()
#
# Fetch and format parameters for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list parameters and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_param_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local param_list_jq='(["NAME", "TYPE", "VERSION", "MODIFIED"] | @tsv),
	                     (.Parameters[] | [.Name, .Type, .Version, (.LastModifiedDate[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch and format parameters (without gum spin - caller handles that)
	aws ssm describe-parameters "${list_args[@]}" --output json |
		jq -r "$param_list_jq" | column -t -s $'\t'
}

# _aws_param_cmd_help()
#
# Display CLI help for parameter commands
#
_aws_param_cmd_help() {
	cat <<'EOF'
aws fzf param - Utility commands for Parameter Store operations

LISTING:
    aws fzf param list [aws-cli-args]

CONSOLE OPERATIONS:
    aws fzf param view-parameter <parameter-name>

CLIPBOARD OPERATIONS:
    aws fzf param copy-value <parameter-name>
    aws fzf param copy-arn <parameter-name>
    aws fzf param copy-name <parameter-name>

DESCRIPTION:
    Utility commands for Parameter Store operations.
    list fetches and formats parameters for fzf display.
    copy-value copies parameter value to clipboard.
    view-parameter opens parameters in the AWS Console.
    copy-arn copies the parameter ARN to clipboard.
    copy-name copies the parameter name to clipboard.

EXAMPLES:
    # List parameters (for fzf reload)
    aws fzf param list --region us-east-1

    # Copy parameter value to clipboard
    aws fzf param copy-value /app/database/password

    # Open in console
    aws fzf param view-parameter /app/database/password

    # Copy identifiers
    aws fzf param copy-arn /app/database/password
    aws fzf param copy-name /app/database/password

EOF
}

# Command router
case "${1:-}" in
list)
	shift
	_aws_param_list_cmd "$@"
	;;
preview)
	_aws_param_help_interactive
	;;
copy-value)
	shift
	_aws_params_copy_value "$@"
	;;
view-parameter)
	shift
	_aws_params_view_parameter "$@"
	;;
copy-arn)
	shift
	_aws_param_copy_arn "$@"
	;;
copy-name)
	shift
	_aws_param_copy_name "$@"
	;;
--help | -h | help | "")
	_aws_param_cmd_help
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws fzf param {list|copy-value|view-parameter|copy-arn|copy-name} [args]"
	gum log --level info "Run 'aws fzf param --help' for more information"
	exit 1
	;;
esac
