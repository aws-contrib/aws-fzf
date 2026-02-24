#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

# aws_ecs_cmd - Batch processing helper for ECS operations
#
# This executable handles batch processing of ECS resources.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_ecs_cmd batch-describe-clusters [aws-cli-args]
#   aws_ecs_cmd batch-describe-services <cluster> [aws-cli-args]
#   aws_ecs_cmd batch-describe-tasks <cluster> [aws-cli-args]
#
# DESCRIPTION:
#   Performs batch processing of AWS ECS API calls to handle API limits.
#   Uses jq's _nwise(10) to batch resources in groups of 10.
#   Outputs JSON array that can be processed with jq -rs.

# Source shared core utilities
_aws_ecs_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_ecs_cmd_source_dir/aws_core.sh"

# _batch_describe_clusters()
#
# List and describe ECS clusters in batches
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   JSON array of cluster descriptions
#
_batch_describe_clusters() {
	local args=("$@")

	aws ecs list-clusters "${args[@]}" --output json |
		jq -r '.clusterArns | _nwise(10) | @sh' |
		while read -r batch; do
			eval "aws ecs describe-clusters --clusters $batch --include STATISTICS --output json"
		done
}

# _batch_describe_services()
#
# List and describe ECS services in a cluster in batches
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $@ - Additional AWS CLI arguments
#
# OUTPUT:
#   JSON array of service descriptions
#
_batch_describe_services() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Missing required parameter: cluster name"
		gum log --level info "Usage: aws_ecs_cmd batch-describe-services <cluster-name> [options]"
		gum log --level info "Run 'aws fzf ecs --help' for more information"
		exit 1
	fi

	shift
	local args=("$@")

	if ! aws ecs list-services --cluster "$cluster" "${args[@]}" --output json |
		jq -r '.serviceArns | _nwise(10) | @sh' |
		while read -r batch; do
			eval "aws ecs describe-services --cluster '$cluster' --services $batch --output json"
		done; then
		gum log --level error "Failed to fetch services for cluster: $cluster"
		gum log --level info "Check that the cluster exists and you have permissions"
		gum log --level info "Run 'aws configure list' to verify AWS credentials"
		exit 1
	fi
}

# _batch_describe_tasks()
#
# List and describe ECS tasks in a cluster in batches
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $@ - Additional AWS CLI arguments (--desired-status, etc.)
#
# OUTPUT:
#   JSON array of task descriptions
#
_batch_describe_tasks() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Missing required parameter: cluster name"
		gum log --level info "Usage: aws_ecs_cmd batch-describe-tasks <cluster-name> [options]"
		gum log --level info "Run 'aws fzf ecs --help' for more information"
		exit 1
	fi

	shift
	local args=("$@")

	if ! aws ecs list-tasks --cluster "$cluster" "${args[@]}" --output json |
		jq -r '.taskArns | _nwise(10) | @sh' |
		while read -r batch; do
			eval "aws ecs describe-tasks --cluster '$cluster' --tasks $batch --output json"
		done; then
		gum log --level error "Failed to fetch tasks for cluster: $cluster"
		gum log --level info "Check that the cluster exists and you have permissions"
		gum log --level info "Run 'aws configure list' to verify AWS credentials"
		exit 1
	fi
}

# _aws_ecs_view_cluster()
#
# Open ECS cluster in AWS Console
#
# PARAMETERS:
#   $1 - Cluster name (required)
#
# DESCRIPTION:
#   Opens the specified ECS cluster in the default web browser
#   via the AWS Console URL
#
_aws_ecs_view_cluster() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://console.aws.amazon.com/ecs/v2/clusters/${cluster}?region=${region}"
}

# _aws_ecs_view_service()
#
# Open ECS service in AWS Console
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $2 - Service name (required)
#
# DESCRIPTION:
#   Opens the specified ECS service in the default web browser
#   via the AWS Console URL
#
_aws_ecs_view_service() {
	local cluster="${1:-}"
	local service="${2:-}"

	if [ -z "$cluster" ] || [ -z "$service" ]; then
		gum log --level error "Cluster name and service name are required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://console.aws.amazon.com/ecs/v2/clusters/${cluster}/services/${service}?region=${region}"
}

# _aws_ecs_view_task()
#
# Open ECS task in AWS Console
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $2 - Task ARN or task ID (required)
#
# DESCRIPTION:
#   Opens the specified ECS task in the default web browser
#   via the AWS Console URL.
#   Handles both full ARNs and short task IDs.
#
_aws_ecs_view_task() {
	local cluster="${1:-}"
	local task="${2:-}"

	if [ -z "$cluster" ] || [ -z "$task" ]; then
		gum log --level error "Cluster name and task identifier are required"
		exit 1
	fi

	# Extract task ID from full ARN if provided
	# ARN format: arn:aws:ecs:region:account:task/cluster/task-id
	local task_id="${task##*/}"

	local region
	region=$(_get_aws_region)

	_open_url "https://console.aws.amazon.com/ecs/v2/clusters/${cluster}/tasks/${task_id}?region=${region}"
}

# _copy_cluster_arn()
#
# Copy cluster ARN to clipboard
#
# PARAMETERS:
#   $1 - Cluster name (required)
#
# DESCRIPTION:
#   Constructs the cluster ARN and copies it to the clipboard
#
_copy_cluster_arn() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster name is required"
		exit 1
	fi

	local region account_id
	region=$(_get_aws_region)
	account_id=$(
		gum spin --title "Getting AWS Caller Identity..." -- \
			aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
	)

	local arn="arn:aws:ecs:${region}:${account_id}:cluster/${cluster}"
	_copy_to_clipboard "$arn" "cluster ARN"
}

# _copy_cluster_name()
#
# Copy cluster name to clipboard
#
# PARAMETERS:
#   $1 - Cluster name (required)
#
# DESCRIPTION:
#   Copies the cluster name to the clipboard
#
_copy_cluster_name() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster name is required"
		exit 1
	fi

	_copy_to_clipboard "$cluster" "cluster name"
}

# _copy_service_arn()
#
# Copy service ARN to clipboard
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $2 - Service name (required)
#
# DESCRIPTION:
#   Constructs the service ARN and copies it to the clipboard
#
_copy_service_arn() {
	local cluster="${1:-}"
	local service="${2:-}"

	if [ -z "$cluster" ] || [ -z "$service" ]; then
		gum log --level error "Cluster name and service name are required"
		exit 1
	fi

	local region account_id
	region=$(_get_aws_region)
	account_id=$(
		gum spin --title "Getting AWS Caller Identity..." -- \
			aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
	)

	local arn="arn:aws:ecs:${region}:${account_id}:service/${cluster}/${service}"
	_copy_to_clipboard "$arn" "service ARN"
}

# _copy_service_name()
#
# Copy service name to clipboard
#
# PARAMETERS:
#   $1 - Service name (required, cluster not needed)
#
# DESCRIPTION:
#   Copies the service name to the clipboard
#
_copy_service_name() {
	local service="${1:-}"

	if [ -z "$service" ]; then
		gum log --level error "Service name is required"
		exit 1
	fi

	_copy_to_clipboard "$service" "service name"
}

# _copy_task_arn()
#
# Copy task ARN to clipboard
#
# PARAMETERS:
#   $1 - Task ARN (required)
#
# DESCRIPTION:
#   Copies the task ARN to the clipboard
#
_copy_task_arn() {
	local task="${1:-}"

	if [ -z "$task" ]; then
		gum log --level error "Task ARN is required"
		exit 1
	fi

	_copy_to_clipboard "$task" "task ARN"
}

# _aws_ecs_cluster_help_interactive()
#
# Display interactive help for ECS clusters view
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_ecs_cluster_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | Return cluster name |
| **`ctrl-o`** | Open in console |
| **`alt-enter`** | List services |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_ecs_service_help_interactive()
#
# Display interactive help for ECS services view
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_ecs_service_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | Return service name |
| **`ctrl-o`** | Open in console |
| **`alt-enter`** | List tasks |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_ecs_task_help_interactive()
#
# Display interactive help for ECS tasks view
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_ecs_task_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open in console |
| **`alt-a`** | Copy ARN |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_ecs_cluster_list_cmd()
#
# Fetch and format ECS clusters for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list and describe ECS clusters and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_ecs_cluster_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local cluster_list_jq='(["NAME", "STATUS", "TASKS", "SERVICES"] | @tsv),
	                       (.clusters[] | [.clusterName, .status, .runningTasksCount, .activeServicesCount] | @tsv)'

	# Fetch and format ECS clusters (without gum spin - caller handles that)
	_batch_describe_clusters "${list_args[@]}" |
		jq -r "$cluster_list_jq" | column -t -s $'\t'
}

# _aws_ecs_service_list_cmd()
#
# Fetch and format ECS services for fzf display
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $@ - Additional AWS CLI arguments
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list and describe ECS services and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_ecs_service_list_cmd() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster name is required"
		exit 1
	fi

	shift
	local list_args=("$@")

	# Define jq formatting for service list
	local service_list_jq='[["NAME", "STATUS", "DESIRED", "RUNNING", "PENDING"]] +
	                       ([.[].services[]] | map([.serviceName, .status, .desiredCount, .runningCount, .pendingCount])) | .[] | @tsv'

	# Fetch and format ECS services (without gum spin - caller handles that)
	_batch_describe_services "$cluster" "${list_args[@]}" |
		jq -rs "$service_list_jq" | column -t -s $'\t'
}

# _aws_ecs_task_list_cmd()
#
# Fetch and format ECS tasks for fzf display
#
# PARAMETERS:
#   $1 - Cluster name (required)
#   $@ - Additional AWS CLI arguments (--desired-status, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list and describe ECS tasks and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_ecs_task_list_cmd() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "Cluster name is required"
		exit 1
	fi

	shift
	local list_args=("$@")

	# Task list jq formatting
	local task_list_jq='[["ARN", "DEFINITION", "DESIRED STATUS", "ACTUAL STATUS"]] +
											([.[].tasks[]] | map([.taskArn, .taskDefinitionArn, .desiredStatus, .healthStatus])) | .[] | @tsv'

	# Fetch and format ECS tasks (without gum spin - caller handles that)
	_batch_describe_tasks "$cluster" "${list_args[@]}" |
		jq -rs "$task_list_jq" | column -t -s $'\t'
}

# Command router
case "${1:-}" in
list-clusters)
	shift
	_aws_ecs_cluster_list_cmd "$@"
	;;
list-services)
	shift
	_aws_ecs_service_list_cmd "$@"
	;;
list-tasks)
	shift
	_aws_ecs_task_list_cmd "$@"
	;;
help-clusters)
	_aws_ecs_cluster_help_interactive
	;;
help-services)
	_aws_ecs_service_help_interactive
	;;
help-tasks)
	_aws_ecs_task_help_interactive
	;;
batch-describe-clusters)
	shift
	_batch_describe_clusters "$@"
	;;
batch-describe-services)
	shift
	_batch_describe_services "$@"
	;;
batch-describe-tasks)
	shift
	_batch_describe_tasks "$@"
	;;
view-cluster)
	shift
	_aws_ecs_view_cluster "$@"
	;;
view-service)
	shift
	_aws_ecs_view_service "$@"
	;;
view-task)
	shift
	_aws_ecs_view_task "$@"
	;;
copy-cluster-arn)
	shift
	_copy_cluster_arn "$@"
	;;
copy-cluster-name)
	shift
	_copy_cluster_name "$@"
	;;
copy-service-arn)
	shift
	_copy_service_arn "$@"
	;;
copy-service-name)
	shift
	_copy_service_name "$@"
	;;
copy-task-arn)
	shift
	_copy_task_arn "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_ecs_cmd - Batch processing and utility commands for ECS operations

LISTING:
    aws_ecs_cmd list-clusters [aws-cli-args]
    aws_ecs_cmd list-services <cluster> [aws-cli-args]
    aws_ecs_cmd list-tasks <cluster> [aws-cli-args]

BATCH PROCESSING:
    aws_ecs_cmd batch-describe-clusters [aws-cli-args]
    aws_ecs_cmd batch-describe-services <cluster> [aws-cli-args]
    aws_ecs_cmd batch-describe-tasks <cluster> [aws-cli-args]

CONSOLE VIEWS:
    aws_ecs_cmd view-cluster <cluster-name>
    aws_ecs_cmd view-service <cluster-name> <service-name>
    aws_ecs_cmd view-task <cluster-name> <task-id>

CLIPBOARD OPERATIONS:
    aws_ecs_cmd copy-cluster-arn <cluster-name>
    aws_ecs_cmd copy-cluster-name <cluster-name>
    aws_ecs_cmd copy-service-arn <cluster-name> <service-name>
    aws_ecs_cmd copy-service-name <service-name>
    aws_ecs_cmd copy-task-arn <task-arn>

DESCRIPTION:
    List commands fetch and format ECS resources for fzf display.
    Batch processing commands perform AWS ECS API calls in batches to handle API limits.
    View commands open ECS resources in the AWS Console via the default browser.
    Clipboard operations copy resource identifiers to the system clipboard.

EXAMPLES:
    # List resources (for fzf reload)
    aws_ecs_cmd list-clusters --region us-east-1
    aws_ecs_cmd list-services my-cluster
    aws_ecs_cmd list-tasks my-cluster --desired-status RUNNING

    # Batch processing
    aws_ecs_cmd batch-describe-clusters --region us-east-1
    aws_ecs_cmd batch-describe-services my-cluster
    aws_ecs_cmd batch-describe-tasks my-cluster --desired-status RUNNING

    # Console views
    aws_ecs_cmd view-cluster my-cluster
    aws_ecs_cmd view-service my-cluster my-service
    aws_ecs_cmd view-task my-cluster abc123def456

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_ecs_cmd {batch-describe-*|view-*} [args]"
	gum log --level info "Run 'aws_ecs_cmd --help' for more information"
	exit 1
	;;
esac
