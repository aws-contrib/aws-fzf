#!/usr/bin/env bash

_fzf_icon=" "

_fzf_options=(
	--ansi
	--border='none'
	--header-lines='1'
	--header-border='sharp'
	--footer-border='sharp'
	--input-border='sharp'
	--color='header:yellow'
	--color='footer:yellow'
	--layout='reverse-list'
)

# aws_core.sh - Shared core utilities for aws-fzf
#
# This file contains shared utility functions used across all AWS service modules.
# Source this file in service command scripts to access common functionality.
#
# USAGE:
#   source "$(dirname "${BASH_SOURCE[0]}")/aws_core.sh"
#
# FUNCTIONS:
#   _get_aws_region()           - Get the current AWS region
#   _open_url()                 - Open URL in default browser (cross-platform)
#   _copy_to_clipboard()        - Copy text to clipboard (cross-platform)
#   _format_timestamp()         - Format timestamp consistently
#   _format_bytes()             - Format bytes to human-readable size
#   _truncate_string()          - Truncate string with ellipsis
#   _validate_required_param()  - Validate required parameters
#   _confirm_sensitive_action() - Confirm sensitive operations

# _get_aws_region()
#
# Get the AWS region for console URLs
#
# DESCRIPTION:
#   Determines the AWS region in the following priority order:
#   1. AWS_REGION environment variable
#   2. AWS_DEFAULT_REGION environment variable
#   3. AWS CLI configured default region
#   4. Fallback to us-east-1
#
# OUTPUT:
#   The AWS region string
#
_get_aws_region() {
	echo "${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || echo 'us-east-1')}}"
}

# _open_url()
#
# Open a URL in the default browser (cross-platform)
#
# PARAMETERS:
#   $1 - URL to open
#
# DESCRIPTION:
#   Opens the specified URL in the default web browser.
#   Supports macOS (open) and Linux (xdg-open)
#
# RETURNS:
#   0 - Success
#   1 - No suitable browser opener found
#
_open_url() {
	local url="$1"

	if command -v open >/dev/null 2>&1; then
		# macOS
		open "$url"
	elif command -v xdg-open >/dev/null 2>&1; then
		# Linux with xdg-utils
		xdg-open "$url"
	else
		gum log --level error "No suitable browser opener found"
		gum log --level info "Install xdg-utils or use macOS"
		return 1
	fi
}

# _copy_to_clipboard()
#
# Copy text to clipboard (cross-platform)
#
# PARAMETERS:
#   $1 - Text to copy
#   $2 - Description (optional, for confirmation message)
#
# DESCRIPTION:
#   Copies the specified text to the system clipboard.
#   Supports:
#   - macOS: pbcopy
#   - Linux X11: xclip, xsel
#   - Linux Wayland: wl-copy
#
# RETURNS:
#   0 - Success
#   1 - No suitable clipboard tool found
#
# EXAMPLES:
#   _copy_to_clipboard "arn:aws:s3:::my-bucket" "ARN"
#   _copy_to_clipboard "my-bucket" "bucket name"
#
_copy_to_clipboard() {
	local text="$1"
	local description="${2:-text}"

	if command -v pbcopy >/dev/null 2>&1; then
		# macOS
		echo -n "$text" | pbcopy
		gum log --level info "Copied $description to clipboard"
	elif command -v xclip >/dev/null 2>&1; then
		# Linux X11 - xclip
		echo -n "$text" | xclip -selection clipboard
		gum log --level info "Copied $description to clipboard"
	elif command -v xsel >/dev/null 2>&1; then
		# Linux X11 - xsel
		echo -n "$text" | xsel --clipboard --input
		gum log --level info "Copied $description to clipboard"
	elif command -v wl-copy >/dev/null 2>&1; then
		# Linux Wayland
		echo -n "$text" | wl-copy
		gum log --level info "Copied $description to clipboard"
	else
		gum log --level error "No clipboard tool found"
		gum log --level info "Install: pbcopy (macOS), xclip/xsel (X11), or wl-copy (Wayland)"
		return 1
	fi
}

# _format_timestamp()
#
# Format timestamp consistently
#
# PARAMETERS:
#   $1 - ISO 8601 timestamp (e.g., "2024-01-15T10:30:45Z")
#
# DESCRIPTION:
#   Converts ISO 8601 timestamp to human-readable format.
#   Output format: "YYYY-MM-DD HH:MM:SS"
#
# OUTPUT:
#   Formatted timestamp string
#
# EXAMPLES:
#   _format_timestamp "2024-01-15T10:30:45Z"
#   # Output: 2024-01-15 10:30:45
#
_format_timestamp() {
	local timestamp="$1"
	# Remove 'T' and everything after seconds (including 'Z' or timezone)
	echo "$timestamp" | sed 's/T/ /' | cut -d'.' -f1 | cut -d'+' -f1 | cut -d'Z' -f1
}

# _format_bytes()
#
# Format bytes to human-readable size
#
# PARAMETERS:
#   $1 - Number of bytes
#
# DESCRIPTION:
#   Converts byte count to human-readable format with appropriate unit.
#   Units: B, KB, MB, GB, TB
#
# OUTPUT:
#   Formatted size string (e.g., "1.5 GB")
#
# EXAMPLES:
#   _format_bytes 1234567890
#   # Output: 1.1 GB
#
_format_bytes() {
	local bytes="$1"

	if [ "$bytes" -lt 1024 ]; then
		echo "${bytes} B"
	elif [ "$bytes" -lt 1048576 ]; then
		echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024}") KB"
	elif [ "$bytes" -lt 1073741824 ]; then
		echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}") MB"
	elif [ "$bytes" -lt 1099511627776 ]; then
		echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1073741824}") GB"
	else
		echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1099511627776}") TB"
	fi
}

# _truncate_string()
#
# Truncate string with ellipsis
#
# PARAMETERS:
#   $1 - String to truncate
#   $2 - Maximum length (default: 50)
#
# DESCRIPTION:
#   Truncates string to specified length and adds "..." if truncated.
#
# OUTPUT:
#   Truncated string
#
# EXAMPLES:
#   _truncate_string "This is a very long description that needs truncating" 30
#   # Output: This is a very long descri...
#
_truncate_string() {
	local string="$1"
	local max_length="${2:-50}"

	if [ "${#string}" -gt "$max_length" ]; then
		echo "${string:0:$((max_length - 3))}..."
	else
		echo "$string"
	fi
}

# _validate_required_param()
#
# Validate required parameters
#
# PARAMETERS:
#   $1 - Parameter name (e.g., "--bucket")
#   $2 - Parameter value
#   $3 - Usage example (optional)
#
# DESCRIPTION:
#   Validates that a required parameter has a value.
#   Logs helpful error messages if validation fails.
#
# RETURNS:
#   0 - Parameter is valid
#   1 - Parameter is missing or empty
#
# EXAMPLES:
#   _validate_required_param "--bucket" "$bucket" "aws fzf s3 object list --bucket my-bucket"
#
_validate_required_param() {
	local param_name="$1"
	local param_value="$2"
	local usage_example="${3:-}"

	if [ -z "$param_value" ]; then
		gum log --level error "Missing required parameter: $param_name"
		if [ -n "$usage_example" ]; then
			gum log --level info "Usage: $usage_example"
		fi
		gum log --level info "Run 'aws fzf --help' for more information"
		return 1
	fi
	return 0
}

# _confirm_sensitive_action()
#
# Confirm sensitive operations
#
# PARAMETERS:
#   $1 - Action description (e.g., "retrieve secret value")
#   $2 - Resource name
#
# DESCRIPTION:
#   Prompts user to confirm sensitive operations.
#   Uses gum confirm for interactive confirmation.
#
# RETURNS:
#   0 - User confirmed
#   1 - User declined
#
# EXAMPLES:
#   _confirm_sensitive_action "retrieve secret value" "my-secret"
#   _confirm_sensitive_action "connect to database" "production-db"
#
_confirm_sensitive_action() {
	local action="$1"
	local resource="$2"

	if ! gum confirm "$action for '$resource'? This may be a sensitive operation."; then
		gum log --level info "Operation cancelled"
		return 1
	fi
	return 0
}
