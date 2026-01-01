#!/usr/bin/env bash
# aws_core.sh - Shared core utilities for aws-fzf
#
# This file contains shared utility functions used across all AWS service modules.
# Source this file in service command scripts to access common functionality.
#
# USAGE:
#   source "$(dirname "${BASH_SOURCE[0]}")/aws_core.sh"
#
# FUNCTIONS:
#   _get_aws_region()  - Get the current AWS region
#   _open_url()        - Open URL in default browser (cross-platform)

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
		echo "Error: No suitable browser opener found" >&2
		echo "Install xdg-utils or use macOS" >&2
		return 1
	fi
}
