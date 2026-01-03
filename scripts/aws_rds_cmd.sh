#!/usr/bin/env bash

# aws_rds_cmd - Batch processing helper for RDS operations
#
# This executable handles batch processing of RDS resources.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_rds_cmd batch-describe-db-instances [aws-cli-args]
#   aws_rds_cmd batch-describe-db-clusters [aws-cli-args]
#   aws_rds_cmd view-instance <db-instance-identifier>
#   aws_rds_cmd view-cluster <db-cluster-identifier>
#
# DESCRIPTION:
#   Performs batch processing of AWS RDS API calls and console viewing.

set -euo pipefail

# Source shared core utilities
_aws_rds_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_rds_cmd_source_dir/aws_core.sh"

# _batch_describe_db_instances()
#
# List and describe RDS DB instances
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   JSON array of DB instance descriptions
#
_batch_describe_db_instances() {
	local args=("$@")

	# RDS describe-db-instances returns all instances in one call
	# No batching needed like ECS (unless we need pagination for large accounts)
	aws rds describe-db-instances "${args[@]}" --output json
}

# _batch_describe_db_clusters()
#
# List and describe RDS DB clusters (Aurora)
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   JSON array of DB cluster descriptions
#
_batch_describe_db_clusters() {
	local args=("$@")

	# RDS describe-db-clusters returns all clusters in one call
	aws rds describe-db-clusters "${args[@]}" --output json
}

# _aws_rds_view_instance()
#
# Open RDS DB instance in AWS Console
#
# PARAMETERS:
#   $1 - DB instance identifier (required)
#
# DESCRIPTION:
#   Opens the specified RDS instance in the default web browser
#   via the AWS Console URL
#
_aws_rds_view_instance() {
	local instance="${1:-}"

	if [ -z "$instance" ]; then
		gum log --level error "DB instance identifier is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/rds/home?region=${region}#database:id=${instance}"
}

# _aws_rds_view_cluster()
#
# Open RDS DB cluster in AWS Console
#
# PARAMETERS:
#   $1 - DB cluster identifier (required)
#
# DESCRIPTION:
#   Opens the specified RDS cluster in the default web browser
#   via the AWS Console URL
#
_aws_rds_view_cluster() {
	local cluster="${1:-}"

	if [ -z "$cluster" ]; then
		gum log --level error "DB cluster identifier is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/rds/home?region=${region}#database:id=${cluster};is-cluster=true"
}

# Command router
case "${1:-}" in
batch-describe-db-instances)
	shift
	_batch_describe_db_instances "$@"
	;;
batch-describe-db-clusters)
	shift
	_batch_describe_db_clusters "$@"
	;;
view-instance)
	shift
	_aws_rds_view_instance "$@"
	;;
view-cluster)
	shift
	_aws_rds_view_cluster "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_rds_cmd - Batch processing and utility commands for RDS operations

BATCH PROCESSING:
    aws_rds_cmd batch-describe-db-instances [aws-cli-args]
    aws_rds_cmd batch-describe-db-clusters [aws-cli-args]

CONSOLE VIEWS:
    aws_rds_cmd view-instance <db-instance-identifier>
    aws_rds_cmd view-cluster <db-cluster-identifier>

DESCRIPTION:
    Batch processing commands perform AWS RDS API calls.
    View commands open RDS resources in the AWS Console via the default browser.

EXAMPLES:
    # Batch processing
    aws_rds_cmd batch-describe-db-instances --region us-east-1
    aws_rds_cmd batch-describe-db-clusters

    # Console views
    aws_rds_cmd view-instance my-database
    aws_rds_cmd view-cluster my-aurora-cluster

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_rds_cmd {batch-describe-*|view-*} [args]"
	gum log --level info "Run 'aws_rds_cmd --help' for more information"
	exit 1
	;;
esac
