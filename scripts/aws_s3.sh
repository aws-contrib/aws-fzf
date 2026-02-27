#!/usr/bin/env bash

[ -z "${DEBUG:-}" ] || set -x

set -euo pipefail

_aws_s3_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_s3_source_dir/aws_core.sh"

# aws_s3.sh - S3 bucket and object browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# S3 bucket and object listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from aws_core.sh (clipboard)

# _aws_s3_bucket_list()
#
# Interactive fuzzy finder for S3 buckets
#
# DESCRIPTION:
#   Displays a list of S3 buckets in an interactive fuzzy finder (fzf)
#   with various keyboard shortcuts for common S3 operations.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure (no buckets found or AWS CLI error)
#
_aws_s3_bucket_list() {
	local list_buckets_args=("$@")

	local bucket_list
	local exit_code=0
	# Call the _cmd script to fetch and format buckets
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	bucket_list="$(
		gum spin --title "Loading AWS S3 Buckets..." -- \
			"$_aws_s3_source_dir/aws_s3_cmd.sh" list-buckets "${list_buckets_args[@]}"
	)" || exit_code=$?

	if [ $exit_code -ne 0 ]; then
		gum log --level error "Failed to list S3 buckets (exit code: $exit_code)"
		gum log --level info "Check your AWS credentials and permissions"
		return 1
	fi

	if [ -z "$bucket_list" ]; then
		gum log --level warn "No S3 buckets found"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Build fzf options with user-provided flags
	_aws_fzf_options "S3_BUCKET"

	# Pre-build reload command with properly quoted args
	local reload_cmd
	reload_cmd="$_aws_s3_source_dir/aws_s3_cmd.sh list-buckets"
	if [[ ${#list_buckets_args[@]} -gt 0 ]]; then
		reload_cmd+="$(printf ' %q' "${list_buckets_args[@]}")"
	fi

	# Display in fzf with bindings
	echo "$bucket_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon S3 Buckets $_fzf_split $aws_context" \
		--preview "$_aws_s3_source_dir/aws_s3_cmd.sh help-buckets" \
		--bind "ctrl-r:reload($reload_cmd)" \
		--bind "ctrl-o:execute-silent($_aws_s3_source_dir/aws_s3_cmd.sh view-bucket {1})" \
		--bind "alt-enter:execute($_aws_s3_source_dir/aws_s3.sh object list --bucket {1})" \
		--bind "alt-a:execute-silent($_aws_s3_source_dir/aws_s3_cmd.sh copy-bucket-arn {1})" \
		--bind "alt-n:execute-silent($_aws_s3_source_dir/aws_s3_cmd.sh copy-bucket-name {1})" \
		--bind "alt-h:toggle-preview"
}

# _aws_s3_object_list()
#
# Interactive fuzzy finder for S3 objects in a bucket
#
# DESCRIPTION:
#   Displays a list of S3 objects for a specific bucket. Requires
#   --bucket parameter.
#
# PARAMETERS:
#   --bucket <bucket>  - Required bucket name
#   $@ - Additional flags passed to AWS CLI (--prefix, --delimiter, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure or missing bucket parameter
#
_aws_s3_object_list() {
	local bucket
	local list_objects_args=()
	# Extract bucket name from arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--bucket)
			bucket="$2"
			shift 2
			;;
		*)
			list_objects_args+=("$1")
			shift
			;;
		esac
	done

	if [ -z "$bucket" ]; then
		gum log --level error "Missing required parameter: --bucket"
		gum log --level info "Usage: aws fzf s3 object list --bucket <bucket>"
		return 1
	fi

	local object_list
	local exit_code=0
	# Call the _cmd script to fetch and format objects
	object_list="$(
		gum spin --title "Loading AWS S3 Objects from $bucket..." -- \
			"$_aws_s3_source_dir/aws_s3_cmd.sh" list-objects "$bucket" "${list_objects_args[@]}"
	)" || exit_code=$?

	if [ $exit_code -ne 0 ]; then
		gum log --level error "Failed to list S3 objects (exit code: $exit_code)"
		gum log --level info "Check your AWS credentials and permissions"
		return 1
	fi

	if [ -z "$object_list" ]; then
		gum log --level warn "No objects found in bucket '$bucket'"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Build fzf options with user-provided flags
	_aws_fzf_options "S3_OBJECT"

	# Pre-build reload command with properly quoted args
	local reload_cmd
	reload_cmd="$_aws_s3_source_dir/aws_s3_cmd.sh list-objects $(printf '%q' "$bucket")"
	if [[ ${#list_objects_args[@]} -gt 0 ]]; then
		reload_cmd+="$(printf ' %q' "${list_objects_args[@]}")"
	fi

	# Display object list with keybindings
	echo "$object_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon S3 Objects $_fzf_split $aws_context $_fzf_split $bucket" \
		--preview "$_aws_s3_source_dir/aws_s3_cmd.sh help-objects" \
		--bind "ctrl-r:reload($reload_cmd)" \
		--bind "enter:execute(aws s3api head-object --bucket \"$bucket\" --key {1} | jq . | gum pager)" \
		--bind "ctrl-o:execute-silent($_aws_s3_source_dir/aws_s3_cmd.sh view-object '$bucket' {1})" \
		--bind "alt-a:execute-silent($_aws_s3_source_dir/aws_s3_cmd.sh copy-object-arn '$bucket' {1})" \
		--bind "alt-n:execute-silent($_aws_s3_source_dir/aws_s3_cmd.sh copy-object-key {1})" \
		--bind "alt-h:toggle-preview"
}

# _aws_s3_help()
#
# Show S3API command help
#
_aws_s3_help() {
	cat <<'EOF'
aws fzf s3 - Interactive S3 bucket and object browser

USAGE:
    aws fzf s3 bucket list [options]
    aws fzf s3 object list --bucket <bucket> [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>       AWS region
    --profile <profile>     AWS profile
    --bucket <bucket>       Bucket name (required for object list)
    --prefix <prefix>       Object prefix filter (RECOMMENDED for large buckets)
    --delimiter <delim>     Delimiter for grouping
    --max-items <number>    Max objects to load (default: 1000)

PERFORMANCE:
    Object listing loads only the first 1000 objects by default.
    For large buckets, use --prefix to filter at the API level:

    Examples:
        --prefix logs/              # All objects under logs/
        --prefix logs/2024/         # Objects in logs/2024/
        --prefix data/prod/         # Objects in data/prod/

KEYBOARD SHORTCUTS:
    Buckets:
        ctrl-r      Reload the list
        ctrl-o      Open bucket in AWS Console
        alt-enter   List objects in bucket
        alt-a       Copy bucket ARN to clipboard
        alt-n       Copy bucket name to clipboard

    Objects:
        ctrl-r      Reload the list
        enter       View object metadata
        ctrl-o      Open object in AWS Console
        alt-a       Copy object ARN to clipboard
        alt-n       Copy object key to clipboard

EXAMPLES:
    # Bucket listing
    aws fzf s3 bucket list
    aws fzf s3 bucket list --region us-west-2
    aws fzf s3 bucket list --profile production

    # Object listing (first 1000 objects)
    aws fzf s3 object list --bucket my-bucket

    # With prefix filter (RECOMMENDED for large buckets)
    aws fzf s3 object list --bucket my-bucket --prefix logs/
    aws fzf s3 object list --bucket my-bucket --prefix logs/2024/01/

    # Load more objects if needed
    aws fzf s3 object list --bucket my-bucket --max-items 5000

SEE ALSO:
    AWS CLI S3: https://docs.aws.amazon.com/cli/latest/reference/s3/
    AWS CLI S3API: https://docs.aws.amazon.com/cli/latest/reference/s3api/
EOF
}

# _aws_s3_main()
#
# Handle s3 resource and action routing
#
# DESCRIPTION:
#   Routes s3 commands using nested resource → action structure.
#   Supports bucket and object resources with list actions.
#
# PARAMETERS:
#   $1 - Resource (bucket|object)
#   $2 - Action (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown resource/action or error
#
_aws_s3_main() {
	local resource="${1:-}"
	shift || true

	case $resource in
	bucket)
		local action="${1:-}"
		shift || true
		case $action in
		list)
			_aws_s3_bucket_list "$@"
			;;
		--help | -h | help | "")
			_aws_s3_help
			;;
		*)
			gum log --level error "Unknown bucket action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf s3 --help' for usage"
			return 1
			;;
		esac
		;;
	object)
		local action="${1:-}"
		shift || true
		case $action in
		list)
			_aws_s3_object_list "$@"
			;;
		--help | -h | help | "")
			_aws_s3_help
			;;
		*)
			gum log --level error "Unknown object action '$action'"
			gum log --level info "Supported: list"
			gum log --level info "Run 'aws fzf s3 --help' for usage"
			return 1
			;;
		esac
		;;
	--help | -h | help | "")
		_aws_s3_help
		;;
	*)
		gum log --level error "Unknown s3 resource '$resource'"
		gum log --level info "Supported: bucket, object"
		gum log --level info "Run 'aws fzf s3 --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_s3_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_s3_main "$@"
fi
