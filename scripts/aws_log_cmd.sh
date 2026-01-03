#!/usr/bin/env bash

# aws_log_cmd - Console view operations for CloudWatch Logs
#
# This executable handles console URL opening for CloudWatch Logs.
#
# USAGE:
#   aws_log_cmd view-group <log-group-name>
#   aws_log_cmd view-stream <log-group-name> <stream-name>
#   aws_log_cmd tail <log-group-name> [stream-name]
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
		gum log --level error "Log group name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	# AWS Console requires double-encoded log group names with $ prefix
	# First URL encode, then replace % with $25
	local encoded_name
	# shellcheck disable=SC2016
	encoded_name=$(printf '%s' "$log_group_name" | jq -sRr @uri | sed 's/%/$25/g')

	_open_url "https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${encoded_name}"
}

# _tail_log()
#
# Tail CloudWatch logs for a log group or specific stream
#
# PARAMETERS:
#   <log-group-name> - Log group name (required, positional)
#   [stream-name]    - Optional stream name (positional). If omitted, tails all streams.
#
# ENVIRONMENT VARIABLES:
#   AWS_FZF_LOG_PAGER - Default pager command (e.g., lnav, less, cat)
#
# DESCRIPTION:
#   Tail CloudWatch logs in real-time.
#   - If stream-name is provided: tails that specific stream
#   - If stream-name is omitted: tails all streams in the log group
#   Exit with Ctrl+C to stop tailing and return.
#
_tail_log() {
	local log_tail_cmd=()
	local log_group_name="${1:-}"
	local log_stream_name="${2:-}"

	log_tail_cmd=(aws logs tail "$log_group_name" --follow --format detailed)
	# Add log stream name if provided
	if [ -n "$log_stream_name" ]; then
		log_tail_cmd+=(--log-stream-names "$log_stream_name")
	fi

	if [[ "$AWS_FZF_LOG_PAGER" == "lnav" ]]; then
		local log_file
		local log_file_name

		# Prepare sanitized temp file name
		log_file_name="$log_group_name$log_stream_name"
		log_file_name="${log_file_name//\//-}"
		log_file_name="${log_file_name#-}"
		log_file_name="${log_file_name%-}"
		# Generate temp file for lnav
		log_file=$(mktemp -t "$log_file_name")
		# shellcheck disable=SC2064
		trap "rm -f '$log_file'" RETURN

		# Pipe output through lnav
		lnav -e "${log_tail_cmd[*]} > $log_file" "$log_file"
	else
		"${log_tail_cmd[@]}"
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
		gum log --level error "Log group name and stream name are required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	# AWS Console requires double-encoded names with $ prefix
	# First URL encode, then replace % with $25
	local encoded_group
	# shellcheck disable=SC2016
	encoded_group=$(printf '%s' "$log_group_name" | jq -sRr @uri | sed 's/%/$25/g')

	local encoded_stream
	# shellcheck disable=SC2016
	encoded_stream=$(printf '%s' "$stream_name" | jq -sRr @uri | sed 's/%/$25/g')

	_open_url "https://${region}.console.aws.amazon.com/cloudwatch/home?region=${region}#logsV2:log-groups/log-group/${encoded_group}/log-events/${encoded_stream}"
}

# Command router
case "${1:-}" in
view-group)
	shift
	_view_log_group "$@"
	;;
view-stream)
	shift
	_view_log_stream "$@"
	;;
tail-log)
	shift
	_tail_log "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_log_cmd - CloudWatch Logs operations

USAGE:
    aws_log_cmd view-group <log-group-name>
    aws_log_cmd view-stream <log-group-name> <stream-name>
    aws_log_cmd tail <log-group-name> [stream-name]

DESCRIPTION:
    View and tail CloudWatch Logs resources.
    - view-group: Opens log group in AWS Console
    - view-stream: Opens log stream in AWS Console
    - tail: Streams logs in real-time (exit with Ctrl+C)
            If stream-name omitted: tails all streams in group
            If stream-name provided: tails specific stream

ENVIRONMENT VARIABLES:
    AWS_FZF_LOG_PAGER   Default pager for tail command (e.g., lnav).
                        Currently only lnav is specially handled.

EXAMPLES:
    # Tail all streams in a log group
    aws_log_cmd tail /aws/lambda/my-function

    # Tail specific stream
    aws_log_cmd tail /aws/lambda/my-function 2025/01/01/[$LATEST]abc123

    # Use lnav for interactive viewing
    export AWS_FZF_LOG_PAGER=lnav
    aws_log_cmd tail /aws/lambda/my-function

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_log_cmd {view-group|view-stream|tail} [args]"
	gum log --level info "Run 'aws_log_cmd --help' for more information"
	exit 1
	;;
esac
