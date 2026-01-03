#!/usr/bin/env bash

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

set -euo pipefail

# Source shared core utilities
_aws_param_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_param_cmd_source_dir/aws_core.sh"

# _aws_params_get_value()
#
# Get parameter value with security confirmation
#
# PARAMETERS:
#   $1 - Parameter name (required)
#
# DESCRIPTION:
#   Retrieves a parameter value from Parameter Store. For SecureString
#   parameters, prompts the user for confirmation before decrypting.
#
_aws_params_get_value() {
	local param_name="${1:-}"

	if [ -z "$param_name" ]; then
		gum log --level error "Parameter name is required"
		exit 1
	fi

	# Get parameter type first
	local param_type
	param_type=$(aws ssm describe-parameters \
		--filters "Key=Name,Values=$param_name" \
		--query 'Parameters[0].Type' --output text 2>/dev/null)

	if [ -z "$param_type" ] || [ "$param_type" = "None" ]; then
		gum log --level error "Parameter not found: $param_name"
		exit 1
	fi

	# Confirm for SecureString
	if [[ "$param_type" == "SecureString" ]]; then
		if ! gum confirm "Retrieve SecureString parameter '$param_name'? Value will be decrypted and visible."; then
			echo "Cancelled" >&2
			exit 1
		fi
	fi

	# Get the value
	aws ssm get-parameter --name "$param_name" --with-decryption | jq .
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
	account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")

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
get-value)
	shift
	_aws_params_get_value "$@"
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

OPERATIONS:
    aws_param_cmd get-value <parameter-name>
    aws_param_cmd view-parameter <parameter-name>

CLIPBOARD OPERATIONS:
    aws_param_cmd copy-arn <parameter-name>
    aws_param_cmd copy-name <parameter-name>

DESCRIPTION:
    Utility commands for Parameter Store operations.
    get-value retrieves parameter values with security confirmation.
    view-parameter opens parameters in the AWS Console.
    copy-arn copies the parameter ARN to clipboard.
    copy-name copies the parameter name to clipboard.

EXAMPLES:
    # Get parameter value
    aws_param_cmd get-value /app/database/password

    # Open in console
    aws_param_cmd view-parameter /app/database/password

    # Clipboard operations
    aws_param_cmd copy-arn /app/database/password
    aws_param_cmd copy-name /app/database/password

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_param_cmd {get-value|view-parameter} [args]"
	gum log --level info "Run 'aws_param_cmd --help' for more information"
	exit 1
	;;
esac
