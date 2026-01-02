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
#   <log-group-name> - Log group name (required, positional)
#   --exec <command> - Optional command to pipe output through
#
# ENVIRONMENT VARIABLES:
#   AWS_FZF_LOG_PAGER - Default pager command (e.g., lnav, less, cat)
#
# DESCRIPTION:
#   Tail CloudWatch logs for all streams in a log group in real-time.
#   Uses 'aws logs tail' without --log-stream-names to tail all streams.
#   Logs from all streams are interleaved chronologically with stream name prefixes.
#   Priority: --exec flag > AWS_FZF_LOG_PAGER > no piping.
#   If a pager is specified and the command exists, pipes output through it.
#   Exit with Ctrl+C to stop tailing and return.
#
_tail_log_group() {
	local log_group_name=""
	local exec_command=""

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--exec)
			if [ -z "${2:-}" ]; then
				echo "Error: --exec requires a command argument" >&2
				exit 1
			fi
			exec_command="$2"
			shift 2
			;;
		*)
			if [ -z "$log_group_name" ]; then
				log_group_name="$1"
				shift
			else
				echo "Error: Unexpected argument '$1'" >&2
				exit 1
			fi
			;;
		esac
	done

	# Validate required parameters
	if [ -z "$log_group_name" ]; then
		echo "Error: Log group name is required" >&2
		exit 1
	fi

	# Priority: --exec flag > AWS_FZF_LOG_PAGER env var > no piping
	if [ -z "$exec_command" ] && [ -n "${AWS_FZF_LOG_PAGER:-}" ]; then
		exec_command="$AWS_FZF_LOG_PAGER"
	fi

	# Execute with or without piping
	if [ -n "$exec_command" ]; then
		local base_command
		base_command=$(echo "$exec_command" | awk '{print $1}')

		if command -v "$base_command" >/dev/null 2>&1; then
			aws logs tail "$log_group_name" \
				--follow \
				--format detailed | eval "$exec_command"
		else
			echo "Warning: Command '$base_command' not found in PATH. Falling back to normal output." >&2
			aws logs tail "$log_group_name" \
				--follow \
				--format detailed
		fi
	else
		# Tail entire log group (all streams)
		# Omitting --log-stream-names tails all streams in the group
		aws logs tail "$log_group_name" \
			--follow \
			--format detailed
	fi
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
#   <log-group-name> - Log group name (required, positional)
#   <stream-name>    - Stream name (required, positional)
#   --exec <command> - Optional command to pipe output through
#
# ENVIRONMENT VARIABLES:
#   AWS_FZF_LOG_PAGER - Default pager command (e.g., lnav, less, cat)
#
# DESCRIPTION:
#   Tail CloudWatch logs for a specific stream in real-time.
#   Uses 'aws logs tail' with --follow to stream new log events.
#   Priority: --exec flag > AWS_FZF_LOG_PAGER > no piping.
#   If a pager is specified and the command exists, pipes output through it.
#   Exit with Ctrl+C to stop tailing and return.
#
_tail_log_stream() {
	local log_group_name=""
	local stream_name=""
	local exec_command=""
	local positional_count=0

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--exec)
			if [ -z "${2:-}" ]; then
				echo "Error: --exec requires a command argument" >&2
				exit 1
			fi
			exec_command="$2"
			shift 2
			;;
		*)
			if [ "$positional_count" -eq 0 ]; then
				log_group_name="$1"
				positional_count=$((positional_count + 1))
				shift
			elif [ "$positional_count" -eq 1 ]; then
				stream_name="$1"
				positional_count=$((positional_count + 1))
				shift
			else
				echo "Error: Unexpected argument '$1'" >&2
				exit 1
			fi
			;;
		esac
	done

	# Validate required parameters
	if [ -z "$log_group_name" ] || [ -z "$stream_name" ]; then
		echo "Error: Log group name and stream name are required" >&2
		exit 1
	fi

	# Priority: --exec flag > AWS_FZF_LOG_PAGER env var > no piping
	if [ -z "$exec_command" ] && [ -n "${AWS_FZF_LOG_PAGER:-}" ]; then
		exec_command="$AWS_FZF_LOG_PAGER"
	fi

	# Execute with or without piping
	if [ -n "$exec_command" ]; then
		local base_command
		base_command=$(echo "$exec_command" | awk '{print $1}')

		if command -v "$base_command" >/dev/null 2>&1; then
			aws logs tail "$log_group_name" \
				--log-stream-names "$stream_name" \
				--follow \
				--format detailed | eval "$exec_command"
		else
			echo "Warning: Command '$base_command' not found in PATH. Falling back to normal output." >&2
			aws logs tail "$log_group_name" \
				--log-stream-names "$stream_name" \
				--follow \
				--format detailed
		fi
	else
		# Tail logs in real-time using AWS CLI
		# The --follow flag will continue streaming logs as they arrive
		# User can exit with Ctrl+C
		aws logs tail "$log_group_name" \
			--log-stream-names "$stream_name" \
			--follow \
			--format detailed
	fi
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
    aws_log_cmd tail-group <log-group-name> [--exec <command>]
    aws_log_cmd view-stream <log-group-name> <stream-name>
    aws_log_cmd tail-stream <log-group-name> <stream-name> [--exec <command>]

DESCRIPTION:
    View and tail CloudWatch Logs resources.
    - view-group: Opens log group in AWS Console
    - tail-group: Streams all logs from the group in real-time (exit with Ctrl+C)
    - view-stream: Opens log stream in AWS Console
    - tail-stream: Streams logs from a specific stream in real-time (exit with Ctrl+C)

ENVIRONMENT VARIABLES:
    AWS_FZF_LOG_PAGER   Default pager for tail commands (e.g., lnav, less, cat).
                        If set and the command exists, tail output is piped through it.
                        Can be overridden per-invocation with --exec flag.

OPTIONS:
    --exec <command>    Override AWS_FZF_LOG_PAGER for this invocation.
                        Pipe tail output through the specified command.
                        Command can include arguments (e.g., "grep ERROR" or "jq -R").

EXAMPLES:
    # Set default pager for all tail commands
    export AWS_FZF_LOG_PAGER=lnav
    aws_log_cmd tail-group /aws/lambda/my-function  # Uses lnav

    # Basic tailing (no pager)
    aws_log_cmd tail-group /aws/lambda/my-function

    # Override pager for one-off filtering
    export AWS_FZF_LOG_PAGER=lnav
    aws_log_cmd tail-group /aws/lambda/my-function --exec "grep ERROR"

    # Disable pager temporarily
    aws_log_cmd tail-group /aws/lambda/my-function --exec cat

    # Stream-specific tailing
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
