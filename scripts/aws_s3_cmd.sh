#!/usr/bin/env bash
# aws_s3_cmd - Utility helper for S3 operations
#
# This executable handles S3 utility operations.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_s3_cmd view-bucket <bucket>
#   aws_s3_cmd view-object <bucket> <key>
#
# DESCRIPTION:
#   Opens S3 resources in the AWS Console via the default browser.

set -euo pipefail

# Source shared core utilities
_aws_s3_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_s3_cmd_source_dir/aws_core.sh"

# _view_bucket()
#
# Open S3 bucket in AWS Console
#
# PARAMETERS:
#   $1 - Bucket name (required)
#
# DESCRIPTION:
#   Opens the specified S3 bucket in the default web browser
#   via the AWS Console URL
#
_view_bucket() {
	local bucket="${1:-}"

	if [ -z "$bucket" ]; then
		echo "Error: Bucket name is required" >&2
		exit 1
	fi

	local region
	region=$(_get_aws_region)
	local url="https://s3.console.aws.amazon.com/s3/buckets/${bucket}?region=${region}"

	_open_url "$url"
}

# _view_object()
#
# Open S3 object in AWS Console
#
# PARAMETERS:
#   $1 - Bucket name (required)
#   $2 - Object key (required)
#
# DESCRIPTION:
#   Opens the specified S3 object in the default web browser
#   via the AWS Console URL.
#   Handles special characters in object keys via URL encoding.
#
_view_object() {
	local bucket="${1:-}"
	local key="${2:-}"

	if [ -z "$bucket" ] || [ -z "$key" ]; then
		echo "Error: Bucket name and object key are required" >&2
		exit 1
	fi

	# Extract object key and URL encode it
	local region
	region=$(_get_aws_region)
	local encoded_key
	encoded_key=$(echo "$key" | jq -sRr @uri)
	local url="https://s3.console.aws.amazon.com/s3/object/${bucket}?region=${region}&prefix=${encoded_key}"

	_open_url "$url"
}

# Command router
case "${1:-}" in
view-bucket)
	shift
	_view_bucket "$@"
	;;
view-object)
	shift
	_view_object "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_s3_cmd - Utility commands for S3 operations

CONSOLE VIEWS:
    aws_s3_cmd view-bucket <bucket-name>
    aws_s3_cmd view-object <bucket-name> <object-key>

DESCRIPTION:
    Opens S3 resources in the AWS Console via the default browser.

EXAMPLES:
    aws_s3_cmd view-bucket my-bucket
    aws_s3_cmd view-object my-bucket path/to/file.txt

EOF
	;;
*)
	echo "Error: Unknown subcommand '${1:-}'" >&2
	echo "Usage: aws_s3_cmd {view-bucket|view-object} [args]" >&2
	echo "Run 'aws_s3_cmd --help' for more information" >&2
	exit 1
	;;
esac
