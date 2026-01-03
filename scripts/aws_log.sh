#!/bin/bash
set -o pipefail

_aws_log_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_log_source_dir/aws_core.sh"

# _aws_log_group_list()
#
# Interactive fuzzy finder for CloudWatch log groups
#
# DESCRIPTION:
#   Displays a list of CloudWatch log groups with statistics in an interactive fzf
#   interface. Users can view details, drill down to streams, or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, --log-group-name-prefix, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_log_group_list() {
	local list_groups_args=("$@")

	local group_list
	# Define jq formatting
	local group_list_jq='(["NAME", "RETENTION", "STORED BYTES", "CREATED"] | @tsv),
	                     (.logGroups[] | [.logGroupName, (.retentionInDays // "Never expire" | tostring), .storedBytes, (.creationTime / 1000 | strftime("%Y-%m-%d"))] | @tsv)'

	# Get and describe log groups
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	group_list="$(
		gum spin --title "Loading AWS CloudWatch Log Groups..." -- \
			aws logs describe-log-groups $list_groups_args --output json |
			jq -r "$group_list_jq" | column -t -s $'\t'
	)"

	# Check if any groups were found
	if [ -z "$group_list" ]; then
		gum log --level warn "No log groups found"
		return 1
	fi

	# Display in fzf with full keybindings
	echo "$group_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon CloudWatch Log Groups" \
		--bind "ctrl-o:execute-silent($_aws_log_source_dir/aws_log_cmd.sh view-group {1})" \
		--bind "alt-t:become($_aws_log_source_dir/aws_log_cmd.sh tail-log {1})" \
		--bind "alt-enter:execute($_aws_log_source_dir/aws_log.sh stream list --log-group-name {1})"
}

# _aws_log_stream_list()
#
# Interactive fuzzy finder for CloudWatch log streams in a log group
#
# DESCRIPTION:
#   Displays a list of CloudWatch log streams for a specific log group. Requires
#   --log-group-name parameter.
#
# PARAMETERS:
#   --log-group-name <name>  - Required log group name
#   $@ - Additional flags passed to AWS CLI (--order-by, --descending, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure or missing log group name parameter
#
_aws_log_stream_list() {
	local log_group_name
	local list_streams_args=()
	# Extract log group name from arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--log-group-name)
			log_group_name="$2"
			shift 2
			;;
		*)
			list_streams_args+=("$1")
			shift
			;;
		esac
	done

	if [ -z "$log_group_name" ]; then
		gum log --level error "Missing required parameter: --log-group-name"
		gum log --level info "Usage: aws fzf logs stream list --log-group-name <name>"
		return 1
	fi

	local stream_list
	# Define jq formatting for stream list
	local stream_list_jq='(["NAME", "LAST EVENT", "INGESTED"] | @tsv),
	                      (.logStreams[] | [.logStreamName, (.lastEventTimestamp / 1000 | strftime("%Y-%m-%d %H:%M:%S")), (.lastIngestionTime / 1000 | strftime("%Y-%m-%d %H:%M:%S"))] | @tsv)'

	# Get and describe streams
	stream_list="$(
		gum spin --title "Loading AWS CloudWatch Log Streams..." -- \
			aws logs describe-log-streams --log-group-name "$log_group_name" --order-by LastEventTime --descending --max-items 1000 "${list_streams_args[@]}" --output json |
			jq -r "$stream_list_jq" | column -t -s $'\t'
	)"

	if [ -z "$stream_list" ]; then
		gum log --level warn "No log streams found in log group '$log_group_name'"
		return 1
	fi

	# Display stream list with keybindings
	echo "$stream_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon CloudWatch Log Streams in $log_group_name" \
		--bind "enter:execute(aws logs describe-log-streams --log-group-name $log_group_name --log-stream-name-prefix {1} --max-items 1 | jq .)+abort" \
		--bind "ctrl-o:execute-silent($_aws_log_source_dir/aws_log_cmd.sh view-stream '$log_group_name' {1})" \
		--bind "alt-t:become($_aws_log_source_dir/aws_log_cmd.sh tail-log '$log_group_name' {1})"
}

# _aws_log_help()
#
# Show CloudWatch Logs command help
#
_aws_log_help() {
	cat <<'EOF'
aws fzf logs - Interactive CloudWatch Logs browser

USAGE:
    aws fzf logs group list [options]
    aws fzf logs stream list --log-group-name <name> [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>                  AWS region
    --profile <profile>                AWS profile
    --log-group-name <name>            Log group name (required for streams)
    --log-group-name-prefix <prefix>   Filter log groups by prefix
    --order-by <field>                 Order streams (LogStreamName|LastEventTime)
    --descending                       Sort in descending order

KEYBOARD SHORTCUTS:
    Log Groups:
        ctrl-o      Open log group in AWS Console
        alt-t       Tail all streams in log group (terminal)
        alt-enter   List streams in log group

    Log Streams:
        enter       Show log stream metadata
        ctrl-o      Open log stream in AWS Console
        alt-t       Tail logs in terminal (follow new events)

EXAMPLES:
    aws fzf logs group list
    aws fzf logs group list --region us-west-2
    aws fzf logs group list --log-group-name-prefix /aws/lambda
    aws fzf logs stream list --log-group-name /aws/lambda/my-function
    aws fzf logs stream list --log-group-name /aws/lambda/my-function --order-by LastEventTime --descending
EOF
}

# aws_log.sh - CloudWatch Logs browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# CloudWatch Logs group and stream listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from utils/ (clipboard, console_url)

# _aws_log_main()
#
# Handle logs resource and action routing
#
# DESCRIPTION:
#   Routes logs commands using nested resource → action structure.
#   Supports group and stream resources with list actions.
#
# PARAMETERS:
#   $1 - Resource (group|stream)
#   $2 - Action (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown resource/action or error
#
_aws_log_main() {
	local resource="$1"
	shift

	case $resource in
	group)
		local action="$1"
		shift
		case $action in
		list)
			_aws_log_group_list "$@"
			;;
		--help | -h | help | "")
			_aws_log_help
			;;
		*)
			gum log --level error "Unknown group action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf logs --help' for usage"
			return 1
			;;
		esac
		;;
	stream)
		local action="$1"
		shift
		case $action in
		list)
			_aws_log_stream_list "$@"
			;;
		--help | -h | help | "")
			_aws_log_help
			;;
		*)
			gum log --level error "Unknown stream action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf logs --help' for usage"
			return 1
			;;
		esac
		;;
	--help | -h | help | "")
		_aws_log_help
		;;
	*)
		gum log --level error "Unknown logs resource '$resource'"
		gum log --level info "Supported: group, stream"
		gum log --level info "Run 'aws fzf logs --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_log_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_log_main "$@"
fi
