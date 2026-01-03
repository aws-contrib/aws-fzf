#!/usr/bin/env bash

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

set -euo pipefail

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
	local cluster="$1"
	shift
	local args=("$@")

	aws ecs list-services --cluster "$cluster" "${args[@]}" --output json |
		jq -r '.serviceArns | _nwise(10) | @sh' |
		while read -r batch; do
			eval "aws ecs describe-services --cluster '$cluster' --services $batch --output json"
		done
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
	local cluster="$1"
	shift
	local args=("$@")

	aws ecs list-tasks --cluster "$cluster" "${args[@]}" --output json |
		jq -r '.taskArns | _nwise(10) | @sh' |
		while read -r batch; do
			eval "aws ecs describe-tasks --cluster '$cluster' --tasks $batch --output json"
		done
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

# Command router
case "${1:-}" in
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
--help | -h | help | "")
	cat <<'EOF'
aws_ecs_cmd - Batch processing and utility commands for ECS operations

BATCH PROCESSING:
    aws_ecs_cmd batch-describe-clusters [aws-cli-args]
    aws_ecs_cmd batch-describe-services <cluster> [aws-cli-args]
    aws_ecs_cmd batch-describe-tasks <cluster> [aws-cli-args]

CONSOLE VIEWS:
    aws_ecs_cmd view-cluster <cluster-name>
    aws_ecs_cmd view-service <cluster-name> <service-name>
    aws_ecs_cmd view-task <cluster-name> <task-id>

DESCRIPTION:
    Batch processing commands perform AWS ECS API calls in batches to handle API limits.
    View commands open ECS resources in the AWS Console via the default browser.

EXAMPLES:
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
