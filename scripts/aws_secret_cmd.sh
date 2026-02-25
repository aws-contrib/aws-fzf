#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

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

# Source shared core utilities
_aws_secret_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_secret_cmd_source_dir/aws_core.sh"

# _aws_secrets_copy_value()
#
# Copy secret value to clipboard
#
# PARAMETERS:
#   $1 - Secret name or ARN (required)
#
# DESCRIPTION:
#   Retrieves a secret value from Secrets Manager and copies it to clipboard.
#   More secure than displaying - value goes to clipboard, not terminal.
#
_aws_secrets_copy_value() {
	local secret_name="${1:-}"

	if [ -z "$secret_name" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	# Get the secret value
	local secret_value
	secret_value=$(
		gum spin --title "Getting AWS Secret Manager $secret_name Secret Value..." -- \
			aws secretsmanager get-secret-value --secret-id "$secret_name" --query SecretString --output text
	)

	if [ -z "$secret_value" ]; then
		gum log --level error "Failed to retrieve secret value"
		exit 1
	fi

	_copy_to_clipboard "$secret_value" "secret value"
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
	local secret_name="${1:-}"

	if [ -z "$secret_name" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	local secret_arn
	secret_arn=$(
		gum spin --title "Getting AWS Secret Manager $secret_name Secret ARN..." -- \
			aws secretsmanager describe-secret --secret-id "$secret_name" --query ARN --output text
	)

	if [ -z "$secret_arn" ]; then
		gum log --level error "Failed to fetch secret ARN"
		exit 1
	fi

	_copy_to_clipboard "$secret_arn" "secret ARN"
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
	local secret_name="${1:-}"

	if [ -z "$secret_name" ]; then
		gum log --level error "Secret name is required"
		exit 1
	fi

	_copy_to_clipboard "$secret_name" "secret name"
}

# _aws_secret_help_interactive()
#
# Display interactive help for secret commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_secret_help_interactive() {
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

# _aws_secret_list_cmd()
#
# Fetch and format secrets for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, --filters, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list secrets and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_secret_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local secrets_list_jq='(["NAME", "DESCRIPTION", "MODIFIED"] | @tsv),
	                       (.SecretList[] | [.Name, ((.Description // "N/A") | if length > 50 then .[0:47] + "..." else . end), (.LastChangedDate[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch and format secrets (without gum spin - caller handles that)
	aws secretsmanager list-secrets "${list_args[@]}" --output json |
		jq -r "$secrets_list_jq" | column -t -s $'\t'
}

# _aws_secret_cmd_help()
#
# Display CLI help for secret commands
#
_aws_secret_cmd_help() {
	cat <<'EOF'
aws_secret_cmd - Utility commands for Secrets Manager operations

LISTING:
    aws_secret_cmd list [aws-cli-args]

CONSOLE OPERATIONS:
    aws_secret_cmd view-secret <secret-name>

CLIPBOARD OPERATIONS:
    aws_secret_cmd copy-value <secret-name>
    aws_secret_cmd copy-arn <secret-name>
    aws_secret_cmd copy-name <secret-name>

DESCRIPTION:
    Utility commands for Secrets Manager operations.
    list fetches and formats secrets for fzf display.
    copy-value copies secret value to clipboard.
    view-secret opens secrets in the AWS Console.
    copy-arn copies the secret ARN to clipboard.
    copy-name copies the secret name to clipboard.

EXAMPLES:
    # List secrets (for fzf reload)
    aws_secret_cmd list --region us-east-1

    # Copy secret value to clipboard
    aws_secret_cmd copy-value my-database-password

    # Open in console
    aws_secret_cmd view-secret my-database-password

    # Copy identifiers
    aws_secret_cmd copy-arn my-database-password
    aws_secret_cmd copy-name my-database-password

EOF
}

# Command router
case "${1:-}" in
list)
	shift
	_aws_secret_list_cmd "$@"
	;;
help)
	_aws_secret_help_interactive
	;;
copy-value)
	shift
	_aws_secrets_copy_value "$@"
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
--help | -h | "")
	_aws_secret_cmd_help
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_secret_cmd {list|copy-value|view-secret|copy-arn|copy-name} [args]"
	gum log --level info "Run 'aws_secret_cmd --help' for more information"
	exit 1
	;;
esac
