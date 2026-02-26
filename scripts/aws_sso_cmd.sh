#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

# aws_sso_cmd - Utility helper for SSO operations
#
# This executable handles SSO operations.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_sso_cmd list
#   aws_sso_cmd login <profile-name>
#   aws_sso_cmd logout <profile-name>
#   aws_sso_cmd open-portal <profile-name>
#   aws_sso_cmd copy-profile-name <profile-name>
#   aws_sso_cmd copy-account-id <profile-name>
#
# DESCRIPTION:
#   Performs SSO operations including listing profiles, login, logout,
#   opening SSO portal, and clipboard operations.

# Source shared core utilities
_aws_sso_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_sso_cmd_source_dir/aws_core.sh"

# _aws_sso_profile_list_cmd()
#
# Fetch and format SSO profiles for fzf display
#
# PARAMETERS:
#   None
#
# OUTPUT:
#   Tab-separated formatted list with header
#   Format: PROFILE  ACCOUNT  ROLE  REGION  SSO_URL
#
# DESCRIPTION:
#   Discovers AWS SSO profiles from ~/.aws/config by parsing profiles
#   that have sso_start_url configured. Fetches profile metadata and
#   formats output for fzf consumption.
#
_aws_sso_profile_list_cmd() {
	local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
	awk -f "$_aws_sso_cmd_source_dir/aws_sso.awk" "$config_file" | column -t -s $'\t'
}

# _aws_sso_login()
#
# Login to an SSO profile
#
# PARAMETERS:
#   $1 - Profile name (required)
#
# DESCRIPTION:
#   Executes aws sso login for the specified profile
#
_aws_sso_login() {
	local profile="${1:-}"

	if [ -z "$profile" ]; then
		gum log --level error "Profile name is required"
		exit 1
	fi

	gum log --level info "Logging in to profile: $profile"

	if aws sso login --profile "$profile"; then
		gum log --level info "Successfully logged in to $profile"
	else
		gum log --level error "Login failed for $profile"
		exit 1
	fi
}

# _aws_sso_logout()
#
# Logout from an SSO profile
#
# PARAMETERS:
#   $1 - Profile name (required)
#
# DESCRIPTION:
#   Executes aws sso logout for the specified profile
#
_aws_sso_logout() {
	local profile="${1:-}"

	if [ -z "$profile" ]; then
		gum log --level error "Profile name is required"
		exit 1
	fi

	gum log --level info "Logging out from profile: $profile"

	if aws sso logout --profile "$profile"; then
		gum log --level info "Successfully logged out from $profile"
	else
		gum log --level error "Logout failed for $profile"
		exit 1
	fi
}

# _aws_sso_open()
#
# Open AWS console for SSO profile
#
# PARAMETERS:
#   $1 - Profile name (required)
#
# DESCRIPTION:
#   Opens the AWS console for the specified SSO profile in the default browser.
#   Constructs a direct console URL with account ID and role name to bypass
#   the SSO account selection page.
#
_aws_sso_open() {
	local profile="${1:-}"

	if [ -z "$profile" ]; then
		gum log --level error "Profile name is required"
		exit 1
	fi

	# Get SSO configuration from profile
	local sso_url
	sso_url=$(aws configure get sso_start_url --profile "$profile" 2>/dev/null) || true

	local account_id
	account_id=$(aws configure get sso_account_id --profile "$profile" 2>/dev/null) || true

	local role_name
	role_name=$(aws configure get sso_role_name --profile "$profile" 2>/dev/null) || true

	local region
	region=$(aws configure get region --profile "$profile" 2>/dev/null) || true

	if [ -z "$sso_url" ]; then
		gum log --level error "SSO start URL not found for profile: $profile"
		exit 1
	fi

	if [ -z "$account_id" ] || [ -z "$role_name" ]; then
		gum log --level error "SSO account ID or role name not found for profile: $profile"
		exit 1
	fi

	# Construct console URL with account and role to bypass account selection
	local console_url="${sso_url}#/console?account_id=${account_id}&region=${region}&role_name=${role_name}"
	_open_url "$console_url"
}

# _aws_sso_copy_profile_name()
#
# Copy profile name to clipboard
#
# PARAMETERS:
#   $1 - Profile name (required)
#
# DESCRIPTION:
#   Copies the profile name to the clipboard
#
_aws_sso_copy_profile_name() {
	local profile="${1:-}"

	if [ -z "$profile" ]; then
		gum log --level error "Profile name is required"
		exit 1
	fi

	_copy_to_clipboard "$profile" "profile name"
}

# _aws_sso_copy_account_id()
#
# Copy account ID to clipboard
#
# PARAMETERS:
#   $1 - Profile name (required)
#
# DESCRIPTION:
#   Fetches the SSO account ID for the profile and copies it to clipboard
#
_aws_sso_copy_account_id() {
	local profile="${1:-}"

	if [ -z "$profile" ]; then
		gum log --level error "Profile name is required"
		exit 1
	fi

	local account_id
	account_id=$(aws configure get sso_account_id --profile "$profile" 2>/dev/null) || true

	if [ -z "$account_id" ]; then
		gum log --level error "Account ID not found for profile: $profile"
		exit 1
	fi

	_copy_to_clipboard "$account_id" "account ID"
}

# _aws_sso_help_interactive()
#
# Display interactive help for SSO commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_sso_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | Return profile name |
| **`ctrl-o`** | Open console |
| **`alt-enter`** | Login |
| **`alt-x`** | Logout |
| **`alt-n`** | Copy name |
| **`alt-a`** | Copy account ID |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_sso_cmd_help()
#
# Display CLI help for SSO commands
#
_aws_sso_cmd_help() {
	cat <<'EOF'
aws fzf sso - Utility commands for SSO operations

LISTING:
    aws fzf sso list

SSO OPERATIONS:
    aws fzf sso login <profile-name>
    aws fzf sso logout <profile-name>
    aws fzf sso open <profile-name>

CLIPBOARD OPERATIONS:
    aws fzf sso copy-profile-name <profile-name>
    aws fzf sso copy-account-id <profile-name>

DESCRIPTION:
    Utility commands for AWS SSO operations.
    list discovers SSO profiles by parsing ~/.aws/config (via Python script)
         and formats them for fzf display using jq (consistent with other commands).
    login authenticates to an SSO profile.
    logout ends the SSO session for a profile.
    open opens the AWS console directly for the profile (bypasses account selection).
    copy-profile-name copies the profile name to clipboard.
    copy-account-id copies the account ID to clipboard.

EXAMPLES:
    # List SSO profiles
    aws fzf sso list

    # Login to a profile
    aws fzf sso login my-sso-profile

    # Logout from a profile
    aws fzf sso logout my-sso-profile

    # Open AWS console for profile
    aws fzf sso open my-sso-profile

    # Clipboard operations
    aws fzf sso copy-profile-name my-sso-profile
    aws fzf sso copy-account-id my-sso-profile

EOF
}

# Command router
case "${1:-}" in
list)
	shift
	_aws_sso_profile_list_cmd "$@"
	;;
preview)
	_aws_sso_help_interactive
	;;
login)
	shift
	_aws_sso_login "$@"
	;;
logout)
	shift
	_aws_sso_logout "$@"
	;;
open)
	shift
	_aws_sso_open "$@"
	;;
copy-profile-name)
	shift
	_aws_sso_copy_profile_name "$@"
	;;
copy-account-id)
	shift
	_aws_sso_copy_account_id "$@"
	;;
--help | -h | help | "")
	_aws_sso_cmd_help
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws fzf sso {list|login|logout|open|copy-profile-name|copy-account-id} [args]"
	gum log --level info "Run 'aws fzf sso --help' for more information"
	exit 1
	;;
esac
