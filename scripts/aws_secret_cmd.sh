#!/usr/bin/env bash

# aws_secret_cmd - Utility helper for Secrets Manager operations
#
# This executable handles Secrets Manager operations.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_secret_cmd get-value <secret-name>
#   aws_secret_cmd view-secret <secret-name>
#
# DESCRIPTION:
#   Performs Secrets Manager operations including getting values
#   and opening secrets in the AWS Console.

set -euo pipefail

# Source shared core utilities
_aws_secret_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_secret_cmd_source_dir/aws_core.sh"

# _aws_secrets_get_value()
#
# Get secret value with security confirmation
#
# PARAMETERS:
#   $1 - Secret name or ARN (required)
#
# DESCRIPTION:
#   Retrieves a secret value from Secrets Manager. Always prompts
#   the user for confirmation before retrieving and displaying.
#
_aws_secrets_get_value() {
	local secret_name="${1:-}"

	if [ -z "$secret_name" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	# Always confirm before retrieving secrets
	if ! gum confirm "Retrieve secret value for '$secret_name'? This will be visible on screen."; then
		echo "Cancelled" >&2
		exit 1
	fi

	# Get the secret value
	aws secretsmanager get-secret-value --secret-id "$secret_name" | jq .
}

# _aws_secrets_view_secret()
#
# Open secret in AWS Console
#
# PARAMETERS:
#   $1 - Secret name or ARN (required)
#
# DESCRIPTION:
#   Opens the specified secret in the default web browser
#   via the AWS Console URL
#
_aws_secrets_view_secret() {
	local secret_name="${1:-}"

	if [ -z "$secret_name" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	local encoded_name
	encoded_name=$(printf '%s' "$secret_name" | jq -sRr @uri)

	_open_url "https://console.aws.amazon.com/secretsmanager/secret?name=${encoded_name}&region=${region}"
}

# _aws_secret_copy_arn()
#
# Copy secret ARN to clipboard
#
# PARAMETERS:
#   $1 - Secret name (required)
#
# DESCRIPTION:
#   Fetches the secret ARN and copies it to the clipboard
#
_aws_secret_copy_arn() {
	local secret="${1:-}"

	if [ -z "$secret" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	local arn
	arn=$(aws secretsmanager describe-secret --secret-id "$secret" --query ARN --output text 2>/dev/null)

	if [ -z "$arn" ]; then
		gum log --level error "Failed to fetch secret ARN"
		exit 1
	fi

	_copy_to_clipboard "$arn" "secret ARN"
}

# _aws_secret_copy_name()
#
# Copy secret name to clipboard
#
# PARAMETERS:
#   $1 - Secret name (required)
#
# DESCRIPTION:
#   Copies the secret name to the clipboard
#
_aws_secret_copy_name() {
	local secret="${1:-}"

	if [ -z "$secret" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	_copy_to_clipboard "$secret" "secret name"
}

# Command router
case "${1:-}" in
get-value)
	shift
	_aws_secrets_get_value "$@"
	;;
view-secret)
	shift
	_aws_secrets_view_secret "$@"
	;;
copy-arn)
	shift
	_aws_secret_copy_arn "$@"
	;;
copy-name)
	shift
	_aws_secret_copy_name "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_secret_cmd - Utility commands for Secrets Manager operations

OPERATIONS:
    aws_secret_cmd get-value <secret-name>
    aws_secret_cmd view-secret <secret-name>

CLIPBOARD OPERATIONS:
    aws_secret_cmd copy-arn <secret-name>
    aws_secret_cmd copy-name <secret-name>

DESCRIPTION:
    Utility commands for Secrets Manager operations.
    get-value retrieves secret values with security confirmation.
    view-secret opens secrets in the AWS Console.
    copy-arn copies the secret ARN to clipboard.
    copy-name copies the secret name to clipboard.

EXAMPLES:
    # Get secret value
    aws_secret_cmd get-value my-database-password

    # Open in console
    aws_secret_cmd view-secret my-database-password

    # Clipboard operations
    aws_secret_cmd copy-arn my-database-password
    aws_secret_cmd copy-name my-database-password

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_secret_cmd {get-value|view-secret} [args]"
	gum log --level info "Run 'aws_secret_cmd --help' for more information"
	exit 1
	;;
esac
