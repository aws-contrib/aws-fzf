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
