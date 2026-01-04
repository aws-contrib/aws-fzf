#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

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

	log_tail_cmd=(aws logs tail "$log_group_name" --follow --format detailed --no-cli-pager)
	# Add log stream name if provided
	if [ -n "$log_stream_name" ]; then
		log_tail_cmd+=(--log-stream-names "$log_stream_name")
	fi

	# Open in pager
	_view_log "${log_tail_cmd[@]}"
}

# _read_log()
#
# List historical CloudWatch log events for a log group or specific stream
#
# PARAMETERS:
#   <log-group-name> - Log group name (required, positional)
#   [stream-name]    - Optional stream name (positional). If omitted, searches all streams.
#
# ENVIRONMENT VARIABLES:
#   AWS_FZF_LOG_VIEWER         - Default pager command (e.g., lnav, less, cat)
#   AWS_FZF_LOG_HISTORY_HOURS - Number of hours to look back (default: 1)
#
# DESCRIPTION:
#   Retrieves historical CloudWatch logs within a time range.
#   - If stream-name is provided: filters to that specific stream
#   - If stream-name is omitted: searches all streams in the log group
#   Displays logs through configured pager (lnav/less/direct output).
#
_read_log() {
	local log_tail_cmd=()
	local log_group_name="${1:-}"
	local log_stream_name="${2:-}"
	local log_start_time
	local log_end_time

	# Get time range
	local hours="${AWS_FZF_LOG_HISTORY_HOURS:-1}"

	log_end_time=$(date +%s)000
	log_start_time=$((($(date +%s) - (hours * 3600)) * 1000))

	log_tail_cmd=(
		aws logs filter-log-events
		--log-group-name "$log_group_name"
		--start-time "$log_start_time"
		--end-time "$log_end_time"
		--limit 10000
		--output json
		--no-cli-pager
	)

	# Add log stream name if provided
	if [ -n "$log_stream_name" ]; then
		log_tail_cmd+=(--log-stream-names "$log_stream_name")
	fi

	# Open in pager
	_view_log "${log_tail_cmd[@]}"
}

_view_log() {
	local log_tail_cmd
	# Construct command to string
	log_tail_cmd="$(printf '%q ' "${@}")"

	if [[ $log_tail_cmd == *filter-log-events* ]]; then
		log_tail_cmd="$log_tail_cmd | jq -r -f $_aws_log_cmd_source_dir/aws_log.jq"
	fi

	if [[ "$AWS_FZF_LOG_VIEWER" == "lnav" ]]; then
		lnav -e "$log_tail_cmd"
	else
		# Interactive: save to temp file and open in pager
		local log_file
		log_file=$(mktemp -t "aws-log-XXXXXX.log")
		# Write logs to temp file and open in less
		bash -c "$log_tail_cmd | tail -a $log_file | less +F"
		# Inform user about the file location
		gum log --level info "Logs saved to: $log_file"
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

# _copy_group_arn()
#
# Copy log group ARN to clipboard
#
# PARAMETERS:
#   $1 - Log group name (required)
#
# DESCRIPTION:
#   Constructs the log group ARN and copies it to the clipboard
#
_copy_group_arn() {
	local log_group="${1:-}"

	if [ -z "$log_group" ]; then
		gum log --level error "Log group name is required"
		exit 1
	fi

	local region account_id
	region=$(_get_aws_region)
	account_id=$(
		aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
	)

	local arn="arn:aws:logs:${region}:${account_id}:log-group:${log_group}:*"
	_copy_to_clipboard "$arn" "log group ARN"
}

# _copy_group_name()
#
# Copy log group name to clipboard
#
# PARAMETERS:
#   $1 - Log group name (required)
#
# DESCRIPTION:
#   Copies the log group name to the clipboard
#
_copy_group_name() {
	local log_group="${1:-}"

	if [ -z "$log_group" ]; then
		gum log --level error "Log group name is required"
		exit 1
	fi

	_copy_to_clipboard "$log_group" "log group name"
}

# _copy_stream_name()
#
# Copy log stream name to clipboard
#
# PARAMETERS:
#   $1 - Stream name (required, log group not needed for simple name copy)
#
# DESCRIPTION:
#   Copies the log stream name to the clipboard
#
_copy_stream_name() {
	local stream="${1:-}"

	if [ -z "$stream" ]; then
		gum log --level error "Stream name is required"
		exit 1
	fi

	_copy_to_clipboard "$stream" "log stream name"
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
read-log)
	shift
	_read_log "$@"
	;;
copy-group-arn)
	shift
	_copy_group_arn "$@"
	;;
copy-group-name)
	shift
	_copy_group_name "$@"
	;;
copy-stream-name)
	shift
	_copy_stream_name "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_log_cmd - CloudWatch Logs operations

CONSOLE VIEWS:
    aws_log_cmd view-group <log-group-name>
    aws_log_cmd view-stream <log-group-name> <stream-name>

LOG OPERATIONS:
    aws_log_cmd tail-log <log-group-name> [stream-name]
    aws_log_cmd read-log <log-group-name> [stream-name]

CLIPBOARD OPERATIONS:
    aws_log_cmd copy-group-arn <log-group-name>
    aws_log_cmd copy-group-name <log-group-name>
    aws_log_cmd copy-stream-name <stream-name>

DESCRIPTION:
    View and tail CloudWatch Logs resources.
    - view-group: Opens log group in AWS Console
    - view-stream: Opens log stream in AWS Console
    - tail-log: Streams logs in real-time (exit with Ctrl+C)
                If stream-name omitted: tails all streams in group
                If stream-name provided: tails specific stream
    - read-log: Read historical logs within a time range
                If stream-name omitted: searches all streams in group
                If stream-name provided: filters to specific stream
    - copy-group-arn: Copies log group ARN to clipboard
    - copy-group-name: Copies log group name to clipboard
    - copy-stream-name: Copies stream name to clipboard

ENVIRONMENT VARIABLES:
    AWS_FZF_LOG_VIEWER          Default pager for log viewing (e.g., lnav, less).
                               Currently only lnav is specially handled.
    AWS_FZF_LOG_HISTORY_HOURS  Number of hours to look back for historical logs (default: 1)

EXAMPLES:
    # Tail all streams in a log group (real-time)
    aws_log_cmd tail-log /aws/lambda/my-function

    # Tail specific stream (real-time)
    aws_log_cmd tail-log /aws/lambda/my-function 2025/01/01/[$LATEST]abc123

    # View last hour of logs (default)
    aws_log_cmd read-log /aws/lambda/my-function

    # View last 24 hours of logs
    export AWS_FZF_LOG_HISTORY_HOURS=24
    aws_log_cmd read-log /aws/lambda/my-function

    # Use lnav for interactive viewing
    export AWS_FZF_LOG_VIEWER=lnav
    aws_log_cmd read-log /aws/lambda/my-function

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_log_cmd {view-group|view-stream|tail} [args]"
	gum log --level info "Run 'aws_log_cmd --help' for more information"
	exit 1
	;;
esac
