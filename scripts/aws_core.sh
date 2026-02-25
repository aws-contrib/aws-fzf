#!/usr/bin/env bash

# Fzf icon for AWS services
_fzf_icon=" "
# Fzf field separator
_fzf_split="·"
# _aws_fzf_options()
#
# Build fzf options array with user-provided flags
#
# DESCRIPTION:
#   Constructs the fzf options array by combining default options with
#   user-provided flags from FZF_AWS_FLAGS environment variable and per-command
#   FZF_AWS_<SERVICE>_<RESOURCE>_OPTS environment variables. This function
#   must be called at runtime (not at source time) to pick up flags set by main().
#
#   Precedence order (last wins):
#   1. Default options (defined in code)
#   2. FZF_AWS_FLAGS (global, set via CLI)
#   3. FZF_AWS_<SERVICE>_<RESOURCE>_OPTS (per-command, highest priority)
#
#   If user flags conflict with defaults (e.g., both specify --height), fzf's
#   last-wins behavior means user flags take precedence.
#
# PARAMETERS:
#   $1 - Optional command identifier (e.g., "SECRET", "S3_BUCKET", "ECS_CLUSTER")
#        Used to lookup per-command environment variable FZF_AWS_${command_id}_OPTS
#
# RETURNS:
#   Sets _fzf_options array with merged options
#
# ENVIRONMENT:
#   FZF_AWS_FLAGS - Space-separated string of user fzf flags (set by main entry point)
#   FZF_AWS_<SERVICE>_<RESOURCE>_OPTS - Per-command fzf options (e.g., FZF_AWS_SECRET_OPTS)
#
# EXAMPLE:
#   # Call this before using fzf in any service function
#   _aws_fzf_options "SECRET"
#   echo "$data" | fzf "${_fzf_options[@]}" ...
#
_aws_fzf_options() {
	local command_id="${1:-}"

	# Default fzf options for aws-fzf
	_fzf_options=(
		--ansi
		--header-lines='1'
		--header-border='sharp'
		--footer-border='sharp'
		--input-border='sharp'
		--color='header:yellow'
		--color='footer:yellow'
		--layout='reverse-list'
		--preview-window='right:40:wrap:hidden'
	)

	# Add user-provided fzf flags (global)
	if [[ -n "$FZF_AWS_FLAGS" ]]; then
		local user_flags=()
		read -ra user_flags <<<"$FZF_AWS_FLAGS"
		_fzf_options+=("${user_flags[@]}")
	fi

	# Add per-command fzf options (highest precedence)
	if [[ -n "$command_id" ]]; then
		local var_name="FZF_AWS_${command_id}_OPTS"
		local cmd_flags="${!var_name}"
		if [[ -n "$cmd_flags" ]]; then
			local cmd_flags_array=()
			read -ra cmd_flags_array <<<"$cmd_flags"
			_fzf_options+=("${cmd_flags_array[@]}")
		fi
	fi
}

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
#   _get_aws_context()          - Get AWS account ID and region (account_id-region_id)
#   _open_url()                 - Open URL in default browser (cross-platform)
#   _copy_to_clipboard()        - Copy text to clipboard (cross-platform)
#   _parse_duration()           - Parse duration string into seconds

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

# _get_aws_context()
#
# Get the AWS account and region context identifier
#
# DESCRIPTION:
#   Returns the AWS account ID and region in the format: account_id-region_id
#   This provides a concrete identifier for displaying where AWS content comes from.
#   Uses STS to get the account ID and _get_aws_region() for the region.
#
# OUTPUT:
#   String in format "account_id-region_id" (e.g., "123456789012-us-east-1")
#   Returns "unknown-region" if STS call fails
#
_get_aws_account_id() {
	aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
}

_get_aws_context() {
	local account_id region
	account_id=$(_get_aws_account_id)
	region=$(_get_aws_region)
	echo "${account_id}-${region}"
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

# _parse_duration()
#
# Parse a duration string into seconds
#
# PARAMETERS:
#   $1 - Duration string (e.g., "15s", "2m", "1h", "1d")
#
# DESCRIPTION:
#   Parses a duration string (e.g., "15s" for 15 seconds, "2m" for 2 minutes,
#   "1h" for 1 hour, "1d" for 1 day) and returns the total duration in seconds.
#   Supports seconds (s), minutes (m), hours (h), and days (d).
#
# RETURNS:
#   The duration in seconds if successful.
#   Returns 1 (and no output) if the format is invalid.
#
# EXAMPLES:
#   _parse_duration "30s"  # Returns 30
#   _parse_duration "5m"   # Returns 300
#   _parse_duration "2h"   # Returns 7200
#   _parse_duration "1d"   # Returns 86400
#
_parse_duration() {
	local value=$1
	local num unit

	[[ $value =~ ^([0-9]+)([smhd])$ ]] || return 1
	num=${BASH_REMATCH[1]}
	unit=${BASH_REMATCH[2]}

	case "$unit" in
	s) echo $((num)) ;;
	m) echo $((num * 60)) ;;
	h) echo $((num * 3600)) ;;
	d) echo $((num * 86400)) ;;
	esac
}
