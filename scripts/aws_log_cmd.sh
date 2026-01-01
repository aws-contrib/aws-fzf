#!/usr/bin/env bash

# aws_log_cmd - Console view operations for CloudWatch Logs
#
# This executable handles console URL opening for CloudWatch Logs.
#
# USAGE:
#   aws_log_cmd view-group <log-group-name>
#   aws_log_cmd view-stream <log-group-name> <stream-name>
#   aws_log_cmd tail-logs <log-group-name> <stream-name>
#
# DESCRIPTION:
#   Opens CloudWatch Logs resources in the AWS Console with proper URL encoding.

set -euo pipefail

# Source shared core utilities
_aws_log_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_log_cmd_source_dir/aws_core.sh"

# _view_log_group()
#
# Open CloudWatch log group in AWS Console
#
# PARAMETERS:
#   $1 - Log group name (required)
#
# DESCRIPTION:
#   Opens the specified log group in the default web browser
#   via the AWS Console URL. Properly encodes special characters
#   in log group names (e.g., /aws/lambda/function-name)
#
_view_log_group() {
	local log_group_name="${1:-}"

	if [ -z "$log_group_name" ]; then
		echo "Error: Log group name is required" >&2
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	# AWS Console requires double-encoded log group names with $ prefix
	# First URL encode, then replace % with $25
	local encoded_name
	encoded_name=$(printf '%s' "$log_group_name" | jq -sRr @uri | sed 's/%/$25/g')

	local url="https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${encoded_name}"

	_open_url "$url"
}

# _tail_log_group()
#
# Tail CloudWatch logs for an entire log group (all streams)
#
# PARAMETERS:
#   $1 - Log group name (required)
#
# DESCRIPTION:
#   Tail CloudWatch logs for all streams in a log group in real-time.
#   Uses 'aws logs tail' without --log-stream-names to tail all streams.
#   Logs from all streams are interleaved chronologically with stream name prefixes.
#   Exit with Ctrl+C to stop tailing and return.
#
_tail_log_group() {
	local log_group_name="${1:-}"

	if [ -z "$log_group_name" ]; then
		echo "Error: Log group name is required" >&2
		exit 1
	fi

	# Tail entire log group (all streams)
	# Omitting --log-stream-names tails all streams in the group
	aws logs tail "$log_group_name" \
		--follow \
		--format detailed
}

# _view_log_stream()
#
# Open CloudWatch log stream in AWS Console
#
# PARAMETERS:
#   $1 - Log group name (required)
#   $2 - Stream name (required)
#
# DESCRIPTION:
#   Opens the specified log stream in the default web browser
#   via the AWS Console URL. Properly encodes special characters
#   in both log group and stream names.
#
_view_log_stream() {
	local log_group_name="${1:-}"
	local stream_name="${2:-}"

	if [ -z "$log_group_name" ] || [ -z "$stream_name" ]; then
		echo "Error: Log group name and stream name are required" >&2
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	# AWS Console requires double-encoded names with $ prefix
	# First URL encode, then replace % with $25
	local encoded_group
	local encoded_stream
	encoded_group=$(printf '%s' "$log_group_name" | jq -sRr @uri | sed 's/%/$25/g')
	encoded_stream=$(printf '%s' "$stream_name" | jq -sRr @uri | sed 's/%/$25/g')

	local url="https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${encoded_group}/log-events/${encoded_stream}"

	_open_url "$url"
}

# _tail_log_stream()
#
# Tail CloudWatch logs for a stream
#
# PARAMETERS:
#   $1 - Log group name (required)
#   $2 - Stream name (required)
#
# DESCRIPTION:
#   Tail CloudWatch logs for a specific stream in real-time.
#   Uses 'aws logs tail' with --follow to stream new log events.
#   Exit with Ctrl+C to stop tailing and return.
#
_tail_log_stream() {
	local log_group_name="${1:-}"
	local stream_name="${2:-}"

	if [ -z "$log_group_name" ] || [ -z "$stream_name" ]; then
		echo "Error: Log group name and stream name are required" >&2
		exit 1
	fi

	# Tail logs in real-time using AWS CLI
	# The --follow flag will continue streaming logs as they arrive
	# User can exit with Ctrl+C
	aws logs tail "$log_group_name" \
		--log-stream-names "$stream_name" \
		--follow \
		--format detailed
}

# Command router
case "${1:-}" in
view-group)
	shift
	_view_log_group "$@"
	;;
tail-group)
	shift
	_tail_log_group "$@"
	;;
view-stream)
	shift
	_view_log_stream "$@"
	;;
tail-stream)
	shift
	_tail_log_stream "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_log_cmd - CloudWatch Logs operations

USAGE:
    aws_log_cmd view-group <log-group-name>
    aws_log_cmd tail-group <log-group-name>
    aws_log_cmd view-stream <log-group-name> <stream-name>
    aws_log_cmd tail-stream <log-group-name> <stream-name>

DESCRIPTION:
    View and tail CloudWatch Logs resources.
    - view-group: Opens log group in AWS Console
    - tail-group: Streams all logs from the group in real-time (exit with Ctrl+C)
    - view-stream: Opens log stream in AWS Console
    - tail-stream: Streams logs from a specific stream in real-time (exit with Ctrl+C)

EXAMPLES:
    aws_log_cmd view-group /aws/lambda/my-function
    aws_log_cmd tail-group /aws/lambda/my-function
    aws_log_cmd view-stream /aws/lambda/my-function 2025/01/01/[$LATEST]abc123
    aws_log_cmd tail-stream /aws/lambda/my-function 2025/01/01/[$LATEST]abc123

EOF
	;;
*)
	echo "Error: Unknown subcommand '${1:-}'" >&2
	echo "Usage: aws_log_cmd {view-group|tail-group|view-stream|tail-stream} [args]" >&2
	echo "Run 'aws_log_cmd --help' for more information" >&2
	exit 1
	;;
esac
