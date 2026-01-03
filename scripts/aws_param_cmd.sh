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
# Copy parameter value to clipboard with security confirmation
#
# PARAMETERS:
#   $1 - Parameter name (required)
#
# DESCRIPTION:
#   Retrieves a parameter value from Parameter Store and copies to clipboard.
#   For SecureString parameters, prompts the user for confirmation before decrypting.
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
		gum spin --title "Getting AWS Parameter Type..." -- \
			aws ssm describe-parameters \
			--filters "Key=Name,Values=$param_name" \
			--query 'Parameters[0].Type' --output text
	)

	if [ -z "$param_type" ] || [ "$param_type" = "None" ]; then
		gum log --level error "Parameter not found: $param_name"
		exit 1
	fi

	# Confirm for SecureString
	if [[ "$param_type" == "SecureString" ]]; then
		if ! gum confirm "Copy SecureString parameter '$param_name' to clipboard? Value will be decrypted."; then
			gum log --level info "Cancelled"
			exit 1
		fi
	fi

	# Get the value
	local param_value
	param_value=$(
		gum spin --title "Getting AWS Parameter Value..." -- \
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
	local param="${1:-}"

	if [ -z "$param" ]; then
		gum log --level error "Parameter name is required"
		exit 1
	fi

	local region account_id
	region=$(_get_aws_region)
	account_id=$(
		gum spin --title "Getting AWS Caller Identity..." -- \
			aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
	)

	# Remove leading slash if present for ARN construction
	local param_path="${param#/}"
	local arn="arn:aws:ssm:${region}:${account_id}:parameter/${param_path}"
	_copy_to_clipboard "$arn" "parameter ARN"
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

# Command router
case "${1:-}" in
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
	cat <<'EOF'
aws_param_cmd - Utility commands for Parameter Store operations

CONSOLE OPERATIONS:
    aws_param_cmd view-parameter <parameter-name>

CLIPBOARD OPERATIONS:
    aws_param_cmd copy-value <parameter-name>
    aws_param_cmd copy-arn <parameter-name>
    aws_param_cmd copy-name <parameter-name>

DESCRIPTION:
    Utility commands for Parameter Store operations.
    copy-value copies parameter value to clipboard (confirms for SecureString).
    view-parameter opens parameters in the AWS Console.
    copy-arn copies the parameter ARN to clipboard.
    copy-name copies the parameter name to clipboard.

EXAMPLES:
    # Copy parameter value to clipboard
    aws_param_cmd copy-value /app/database/password

    # Open in console
    aws_param_cmd view-parameter /app/database/password

    # Copy identifiers
    aws_param_cmd copy-arn /app/database/password
    aws_param_cmd copy-name /app/database/password

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_param_cmd {copy-value|view-parameter|copy-arn|copy-name} [args]"
	gum log --level info "Run 'aws_param_cmd --help' for more information"
	exit 1
	;;
esac
