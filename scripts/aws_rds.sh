#!/bin/bash
set -o pipefail

_aws_rds_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_rds_source_dir/aws_core.sh"

# _aws_rds_instance_list()
#
# Interactive fuzzy finder for RDS DB instances
#
# DESCRIPTION:
#   Displays a list of RDS DB instances in an interactive fzf interface.
#   Users can view details or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_rds_instance_list() {
	local list_instances_args=("$@")

	local instance_list
	# Define jq formatting
	local instance_list_jq='(["ID", "ENGINE", "STATUS", "CLASS"] | @tsv),
	                        (.DBInstances[] | [.DBInstanceIdentifier, .Engine, .DBInstanceStatus, .DBInstanceClass] | @tsv)'

	# Fetch DB instances
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	instance_list="$(
		gum spin --title "Loading AWS RDS Instances..." -- \
			aws rds describe-db-instances $list_instances_args --output json |
			jq -r "$instance_list_jq" | column -t -s $'\t'
	)"

	# Check if any instances were found
	if [ -z "$instance_list" ]; then
		gum log --level warn "No RDS instances found"
		return 1
	fi

	# Display in fzf with full keybindings
	echo "$instance_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon RDS Instances" \
		--bind "ctrl-o:execute-silent($_aws_rds_source_dir/aws_rds_cmd.sh view-instance {1})" \
		--bind "enter:execute(aws rds describe-db-instances --db-instance-identifier {1} | jq .)+abort" \
		--bind "alt-c:become($_aws_rds_source_dir/aws_rds_cmd.sh connect-instance {1})" \
		--bind "alt-a:execute-silent($_aws_rds_source_dir/aws_rds_cmd.sh copy-instance-arn {1})" \
		--bind "alt-n:execute-silent($_aws_rds_source_dir/aws_rds_cmd.sh copy-instance-name {1})"
}

# _aws_rds_cluster_list()
#
# Interactive fuzzy finder for RDS DB clusters (Aurora)
#
# DESCRIPTION:
#   Displays a list of RDS Aurora clusters in an interactive fzf interface.
#   Users can view details or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_rds_cluster_list() {
	local list_clusters_args=("$@")

	local cluster_list
	# Define jq formatting
	local cluster_list_jq='(["ID", "ENGINE", "STATUS", "MEMBERS"] | @tsv),
	                       (.DBClusters[] | [.DBClusterIdentifier, .Engine, .Status, (.DBClusterMembers | length)] | @tsv)'

	# Fetch DB clusters
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	cluster_list="$(
		gum spin --title "Loading AWS RDS Clusters..." -- \
			aws rds describe-db-clusters $list_clusters_args --output json |
			jq -r "$cluster_list_jq" | column -t -s $'\t'
	)"

	# Check if any clusters were found
	if [ -z "$cluster_list" ]; then
		gum log --level warn "No RDS clusters found"
		return 1
	fi

	# Display in fzf with full keybindings
	echo "$cluster_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon RDS Clusters" \
		--bind "ctrl-o:execute-silent($_aws_rds_source_dir/aws_rds_cmd.sh view-cluster {1})" \
		--bind "enter:execute(aws rds describe-db-clusters --db-cluster-identifier {1} | jq .)+abort" \
		--bind "alt-c:become($_aws_rds_source_dir/aws_rds_cmd.sh connect-cluster {1})" \
		--bind "alt-a:execute-silent($_aws_rds_source_dir/aws_rds_cmd.sh copy-cluster-arn {1})" \
		--bind "alt-n:execute-silent($_aws_rds_source_dir/aws_rds_cmd.sh copy-cluster-name {1})"
}

# _aws_rds_help()
#
# Show RDS command help
#
_aws_rds_help() {
	cat <<'EOF'
aws fzf rds - Interactive RDS database browser

USAGE:
    aws fzf rds instance list [options]
    aws fzf rds cluster list [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile
    --filters <filters>         RDS filters

KEYBOARD SHORTCUTS:
    All resources:
        ctrl-o      Open resource in AWS Console
        enter       View resource details (full JSON)
        alt-c       Connect to database with psql (PostgreSQL only, requires IAM auth)
        alt-a       Copy resource ARN to clipboard
        alt-n       Copy resource identifier to clipboard

SECURITY:
    Database connections (alt-c) require:
    - PostgreSQL engine (postgres or aurora-postgresql)
    - IAM database authentication enabled on the instance/cluster
    - IAM policy allowing rds-db:connect action
    - psql client installed (brew install postgresql)

    IAM auth tokens are valid for 15 minutes and provide secure, temporary access.
    Use caution when connecting to production databases.

PERFORMANCE:
    RDS listing APIs paginate automatically.
    Each describe-db-instances call returns up to 100 instances.
    Each describe-db-clusters call returns up to 100 clusters.
    Use --filters to narrow results at the API level if needed.

EXAMPLES:
    # List all RDS instances
    aws fzf rds instance list

    # List instances in specific region
    aws fzf rds instance list --region us-west-2

    # List instances with specific profile
    aws fzf rds instance list --profile production

    # List all Aurora clusters
    aws fzf rds cluster list

    # List clusters in specific region
    aws fzf rds cluster list --region eu-west-1 --profile prod

SEE ALSO:
    AWS CLI RDS: https://docs.aws.amazon.com/cli/latest/reference/rds/
    IAM Database Authentication: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html
EOF
}

# aws_rds.sh - RDS database browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# RDS DB instance and cluster listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from aws_core.sh

# _aws_rds_main()
#
# Handle rds resource and action routing
#
# DESCRIPTION:
#   Routes rds commands using nested resource → action structure.
#   Supports instance and cluster resources with list actions.
#
# PARAMETERS:
#   $1 - Resource (instance|cluster)
#   $2 - Action (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown resource/action or error
#
_aws_rds_main() {
	local resource="$1"
	shift

	case $resource in
	instance)
		local action="$1"
		shift
		case $action in
		list)
			_aws_rds_instance_list "$@"
			;;
		--help | -h | help | "")
			_aws_rds_help
			;;
		*)
			gum log --level error "Unknown instance action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf rds --help' for usage"
			return 1
			;;
		esac
		;;
	cluster)
		local action="$1"
		shift
		case $action in
		list)
			_aws_rds_cluster_list "$@"
			;;
		--help | -h | help | "")
			_aws_rds_help
			;;
		*)
			gum log --level error "Unknown cluster action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf rds --help' for usage"
			return 1
			;;
		esac
		;;
	--help | -h | help | "")
		_aws_rds_help
		;;
	*)
		gum log --level error "Unknown rds resource '$resource'"
		gum log --level info "Supported: instance, cluster"
		gum log --level info "Run 'aws fzf rds --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_rds_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_rds_main "$@"
fi
