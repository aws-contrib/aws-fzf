#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

_aws_ecs_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_ecs_source_dir/aws_core.sh"

# _aws_ecs_cluster_list()
#
# Interactive fuzzy finder for ECS clusters
#
# DESCRIPTION:
#   Displays a list of ECS clusters with statistics in an interactive fzf
#   interface. Users can view details, drill down to services/tasks, or
#   open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_ecs_cluster_list() {
	local list_clusters_args=("$@")

	local cluster_list
	# Call the _cmd script to fetch and format clusters
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	cluster_list="$(
		gum spin --title "Loading AWS ECS Clusters..." -- \
			"$_aws_ecs_source_dir/aws_ecs_cmd.sh" list-clusters "${list_clusters_args[@]}"
	)"

	# Check if any clusters were found
	if [ -z "$cluster_list" ]; then
		gum log --level warn "No clusters found"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Display in fzf with full keybindings
	echo "$cluster_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon ECS Clusters $_fzf_split $aws_context" \
		--bind "ctrl-r:reload($_aws_ecs_source_dir/aws_ecs_cmd.sh list-clusters ${list_clusters_args[*]})" \
		--bind "ctrl-o:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh view-cluster {1})" \
		--bind "alt-enter:execute($_aws_ecs_source_dir/aws_ecs.sh service list --cluster {1})" \
		--bind "alt-a:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh copy-cluster-arn {1})" \
		--bind "alt-n:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh copy-cluster-name {1})"
}

# _aws_ecs_service_list()
#
# Interactive fuzzy finder for ECS services in a cluster
#
# DESCRIPTION:
#   Displays a list of ECS services for a specific cluster. Requires
#   --cluster parameter.
#
# PARAMETERS:
#   --cluster <cluster>  - Required cluster name
#   $@ - Additional flags passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Failure or missing cluster parameter
#
_aws_ecs_service_list() {
	local cluster
	local list_services_args=()
	# Extract cluster name from arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--cluster)
			cluster="$2"
			shift 2
			;;
		*)
			list_services_args+=("$1")
			shift
			;;
		esac
	done

	if [ -z "$cluster" ]; then
		gum log --level error "Missing required parameter: --cluster"
		gum log --level info "Usage: aws fzf ecs service list --cluster <cluster>"
		return 1
	fi

	local service_list
	# Call the _cmd script to fetch and format services
	service_list="$(
		gum spin --title "Loading AWS ECS Services from $cluster..." -- \
			"$_aws_ecs_source_dir/aws_ecs_cmd.sh" list-services "$cluster" "${list_services_args[@]}"
	)"

	if [ -z "$service_list" ]; then
		gum log --level warn "No services found in cluster '$cluster'"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Display service list with keybindings
	echo "$service_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon ECS Services $_fzf_split $aws_context $_fzf_split $cluster" \
		--bind "ctrl-r:reload($_aws_ecs_source_dir/aws_ecs_cmd.sh list-services '$cluster' ${list_services_args[*]})" \
		--bind "ctrl-o:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh view-service $cluster {1})" \
		--bind "alt-enter:execute($_aws_ecs_source_dir/aws_ecs.sh task list --cluster $cluster --service-name {1})" \
		--bind "alt-a:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh copy-service-arn $cluster {1})" \
		--bind "alt-n:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh copy-service-name {1})"
}

# _aws_ecs_task_list()
#
# Interactive fuzzy finder for ECS tasks in a cluster
#
# DESCRIPTION:
#   Displays a list of ECS tasks for a specific cluster. Requires
#   --cluster parameter.
#
# PARAMETERS:
#   --cluster <cluster>  - Required cluster name
#   $@ - Additional flags passed to AWS CLI (e.g., --desired-status)
#
# RETURNS:
#   0 - Success
#   1 - Failure or missing cluster parameter
#
_aws_ecs_task_list() {
	local cluster
	local list_tasks_args=()
	# Extract cluster name from arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--cluster)
			cluster="$2"
			shift 2
			;;
		*)
			list_tasks_args+=("$1")
			shift
			;;
		esac
	done

	if [ -z "$cluster" ]; then
		gum log --level error "Missing required parameter: --cluster"
		gum log --level info "Usage: aws fzf ecs task list --cluster <cluster>"
		return 1
	fi

	local task_list
	# Call the _cmd script to fetch and format tasks
	task_list="$(
		gum spin --title "Loading AWS ECS Tasks from $cluster..." -- \
			"$_aws_ecs_source_dir/aws_ecs_cmd.sh" list-tasks "$cluster" "${list_tasks_args[@]}"
	)"

	if [ -z "$task_list" ]; then
		gum log --level warn "No tasks found in cluster '$cluster'"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Display task IDs with on-demand preview
	echo "$task_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon ECS Tasks $_fzf_split $aws_context $_fzf_split $cluster" \
		--bind "ctrl-r:reload($_aws_ecs_source_dir/aws_ecs_cmd.sh list-tasks '$cluster' ${list_tasks_args[*]})" \
		--bind "enter:execute(aws ecs describe-tasks --cluster $cluster --tasks {1} | jq .)+abort" \
		--bind "ctrl-o:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh view-task $cluster {1})" \
		--bind "alt-a:execute-silent($_aws_ecs_source_dir/aws_ecs_cmd.sh copy-task-arn {1})"
}

# _aws_ecs_help()
#
# Show ECS command help
#
_aws_ecs_help() {
	cat <<'EOF'
aws fzf ecs - Interactive ECS browser

USAGE:
    aws fzf ecs cluster list [options]
    aws fzf ecs service list --cluster <cluster> [options]
    aws fzf ecs task list --cluster <cluster> [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile
    --cluster <cluster>         Cluster name (required for services/tasks)
    --status <status>           Service/task status filter
    --desired-status <status>   Task desired status filter

KEYBOARD SHORTCUTS:
    Clusters:
        ctrl-r      Reload the list
        ctrl-o      Open cluster in AWS Console
        alt-enter   List services in cluster
        alt-a       Copy cluster ARN to clipboard
        alt-n       Copy cluster name to clipboard

    Services:
        ctrl-r      Reload the list
        ctrl-o      Open service in AWS Console
        alt-enter   List tasks for service
        alt-a       Copy service ARN to clipboard
        alt-n       Copy service name to clipboard

    Tasks:
        ctrl-r      Reload the list
        enter       Show task details
        ctrl-o      Open task in AWS Console
        alt-a       Copy task ARN to clipboard

PERFORMANCE:
    ECS resources are fetched in batches to handle API limits:
    - Clusters: Listed and described in batches of 100
    - Services: Listed and described in batches of 10
    - Tasks: Listed and described in batches of 100

    For clusters with many services/tasks, initial loading may take a few seconds.
    Use --desired-status to filter tasks (RUNNING, STOPPED, etc.) at the API level.

EXAMPLES:
    # List all ECS clusters
    aws fzf ecs cluster list

    # List clusters in specific region
    aws fzf ecs cluster list --region us-west-2

    # List services in a cluster
    aws fzf ecs service list --cluster my-cluster

    # List services with specific profile
    aws fzf ecs service list --cluster my-cluster --profile production

    # List running tasks only
    aws fzf ecs task list --cluster my-cluster --desired-status RUNNING

    # List all tasks (running and stopped)
    aws fzf ecs task list --cluster my-cluster

SEE ALSO:
    AWS CLI ECS: https://docs.aws.amazon.com/cli/latest/reference/ecs/
EOF
}

# aws_ecs.sh - ECS cluster/service/task browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# ECS cluster, service, and task listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from utils/ (clipboard, console_url)

# _aws_ecs_main()
#
# Handle ecs resource and action routing
#
# DESCRIPTION:
#   Routes ecs commands using nested resource → action structure.
#   Supports cluster, service, and task resources with list actions.
#
# PARAMETERS:
#   $1 - Resource (cluster|service|task)
#   $2 - Action (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown resource/action or error
#
_aws_ecs_main() {
	local resource="$1"
	shift

	case $resource in
	cluster)
		local action="$1"
		shift
		case $action in
		list)
			_aws_ecs_cluster_list "$@"
			;;
		--help | -h | help | "")
			_aws_ecs_help
			;;
		*)
			gum log --level error "Unknown cluster action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf ecs --help' for usage"
			return 1
			;;
		esac
		;;
	service)
		local action="$1"
		shift
		case $action in
		list)
			_aws_ecs_service_list "$@"
			;;
		--help | -h | help | "")
			_aws_ecs_help
			;;
		*)
			gum log --level error "Unknown service action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf ecs --help' for usage"
			return 1
			;;
		esac
		;;
	task)
		local action="$1"
		shift
		case $action in
		list)
			_aws_ecs_task_list "$@"
			;;
		--help | -h | help | "")
			_aws_ecs_help
			;;
		*)
			gum log --level error "Unknown task action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf ecs --help' for usage"
			return 1
			;;
		esac
		;;
	--help | -h | help | "")
		_aws_ecs_help
		;;
	*)
		gum log --level error "Unknown ecs resource '$resource'"
		gum log --level info "Supported: cluster, service, task"
		gum log --level info "Run 'aws fzf ecs --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to hsdk-env.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_ecs_main "$@"
fi
