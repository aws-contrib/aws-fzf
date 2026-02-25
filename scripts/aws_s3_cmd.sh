#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

# aws_s3_cmd - Utility helper for S3 operations
#
# This executable handles S3 utility operations.
# Designed to be called by gum spin which runs in a subprocess.
#
# USAGE:
#   aws_s3_cmd view-bucket <bucket>
#   aws_s3_cmd view-object <bucket> <key>
#
# DESCRIPTION:
#   Opens S3 resources in the AWS Console via the default browser.

# Source shared core utilities
_aws_s3_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_s3_cmd_source_dir/aws_core.sh"

# _aws_s3_view_bucket()
#
# Open S3 bucket in AWS Console
#
# PARAMETERS:
#   $1 - Bucket name (required)
#
# DESCRIPTION:
#   Opens the specified S3 bucket in the default web browser
#   via the AWS Console URL
#
_aws_s3_view_bucket() {
	local bucket="${1:-}"

	if [ -z "$bucket" ]; then
		gum log --level error "Bucket name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://s3.console.aws.amazon.com/s3/buckets/${bucket}?region=${region}"
}

# _aws_s3_view_object()
#
# Open S3 object in AWS Console
#
# PARAMETERS:
#   $1 - Bucket name (required)
#   $2 - Object key (required)
#
# DESCRIPTION:
#   Opens the specified S3 object in the default web browser
#   via the AWS Console URL.
#   Handles special characters in object keys via URL encoding.
#
_aws_s3_view_object() {
	local bucket="${1:-}"
	local key="${2:-}"

	if [ -z "$bucket" ] || [ -z "$key" ]; then
		gum log --level error "Bucket name and object key are required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	local encoded_key
	encoded_key=$(echo "$key" | jq -sRr @uri)

	_open_url "https://s3.console.aws.amazon.com/s3/object/${bucket}?region=${region}&prefix=${encoded_key}"
}

# _aws_s3_copy_bucket_arn()
#
# Copy bucket ARN to clipboard
#
# PARAMETERS:
#   $1 - Bucket name (required)
#
# DESCRIPTION:
#   Constructs the bucket ARN and copies it to the clipboard
#
_aws_s3_copy_bucket_arn() {
	local bucket="${1:-}"

	if [ -z "$bucket" ]; then
		gum log --level error "Bucket name is required"
		exit 1
	fi

	local arn="arn:aws:s3:::${bucket}"
	_copy_to_clipboard "$arn" "bucket ARN"
}

# _aws_s3_copy_bucket_name()
#
# Copy bucket name to clipboard
#
# PARAMETERS:
#   $1 - Bucket name (required)
#
# DESCRIPTION:
#   Copies the bucket name to the clipboard
#
_aws_s3_copy_bucket_name() {
	local bucket="${1:-}"

	if [ -z "$bucket" ]; then
		gum log --level error "Bucket name is required"
		exit 1
	fi

	_copy_to_clipboard "$bucket" "bucket name"
}

# _aws_s3_copy_object_arn()
#
# Copy object ARN to clipboard
#
# PARAMETERS:
#   $1 - Bucket name (required)
#   $2 - Object key (required)
#
# DESCRIPTION:
#   Constructs the object ARN and copies it to the clipboard
#
_aws_s3_copy_object_arn() {
	local bucket="${1:-}"
	local key="${2:-}"

	if [ -z "$bucket" ] || [ -z "$key" ]; then
		gum log --level error "Bucket name and object key are required"
		exit 1
	fi

	local arn="arn:aws:s3:::${bucket}/${key}"
	_copy_to_clipboard "$arn" "object ARN"
}

# _aws_s3_copy_object_key()
#
# Copy object key to clipboard
#
# PARAMETERS:
#   $1 - Object key (required, bucket not needed)
#
# DESCRIPTION:
#   Copies the object key to the clipboard
#
_aws_s3_copy_object_key() {
	local key="${1:-}"

	if [ -z "$key" ]; then
		gum log --level error "Object key is required"
		exit 1
	fi

	_copy_to_clipboard "$key" "object key"
}

# _aws_s3_bucket_help_interactive()
#
# Display interactive help for S3 bucket view
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_s3_bucket_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | Return bucket name |
| **`ctrl-o`** | Open in console |
| **`alt-enter`** | List objects |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_s3_object_help_interactive()
#
# Display interactive help for S3 object view
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_s3_object_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open in console |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy key |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_s3_bucket_list_cmd()
#
# Fetch and format S3 buckets for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list S3 buckets and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_s3_bucket_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local bucket_list_jq='(["NAME", "CREATED"] | @tsv),
	                (.Buckets[] | [.Name, (.CreationDate[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch and format S3 buckets (without gum spin - caller handles that)
	aws s3api list-buckets "${list_args[@]}" --output json |
		jq -r "$bucket_list_jq" | column -t -s $'\t'
}

# _aws_s3_object_list_cmd()
#
# Fetch and format S3 objects for fzf display
#
# PARAMETERS:
#   $1 - Bucket name (required)
#   $@ - Additional AWS CLI arguments (--prefix, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list S3 objects in a bucket and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_s3_object_list_cmd() {
	local bucket="${1:-}"

	if [ -z "$bucket" ]; then
		gum log --level error "Bucket name is required"
		exit 1
	fi

	shift
	local list_args=("$@")

	# Define jq formatting for object list
	local object_list_jq='[["KEY", "SIZE", "STORAGE CLASS", "MODIFIED"]] +
	                      ([.Contents[]? // []] | map([.Key, .Size, .StorageClass, (.LastModified[0:19] | gsub("T"; " "))])) | .[] | @tsv'

	# Fetch and format S3 objects (without gum spin - caller handles that)
	aws s3api list-objects-v2 --bucket "$bucket" --max-items 1000 "${list_args[@]}" --output json |
		jq -r "$object_list_jq" | column -t -s $'\t'
}

# Command router
case "${1:-}" in
list-buckets)
	shift
	_aws_s3_bucket_list_cmd "$@"
	;;
list-objects)
	shift
	_aws_s3_object_list_cmd "$@"
	;;
help-buckets)
	_aws_s3_bucket_help_interactive
	;;
help-objects)
	_aws_s3_object_help_interactive
	;;
view-bucket)
	shift
	_aws_s3_view_bucket "$@"
	;;
view-object)
	shift
	_aws_s3_view_object "$@"
	;;
copy-bucket-arn)
	shift
	_aws_s3_copy_bucket_arn "$@"
	;;
copy-bucket-name)
	shift
	_aws_s3_copy_bucket_name "$@"
	;;
copy-object-arn)
	shift
	_aws_s3_copy_object_arn "$@"
	;;
copy-object-key)
	shift
	_aws_s3_copy_object_key "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_s3_cmd - Utility commands for S3 operations

LISTING:
    aws_s3_cmd list-buckets [aws-cli-args]
    aws_s3_cmd list-objects <bucket-name> [aws-cli-args]

CONSOLE VIEWS:
    aws_s3_cmd view-bucket <bucket-name>
    aws_s3_cmd view-object <bucket-name> <object-key>

CLIPBOARD OPERATIONS:
    aws_s3_cmd copy-bucket-arn <bucket-name>
    aws_s3_cmd copy-bucket-name <bucket-name>
    aws_s3_cmd copy-object-arn <bucket-name> <object-key>
    aws_s3_cmd copy-object-key <object-key>

DESCRIPTION:
    list-buckets/list-objects: Fetches and formats S3 resources for fzf display.
    Opens S3 resources in the AWS Console via the default browser.
    Clipboard operations copy resource identifiers to the system clipboard.

EXAMPLES:
    # List resources (for fzf reload)
    aws_s3_cmd list-buckets
    aws_s3_cmd list-objects my-bucket --prefix logs/

    # Console views
    aws_s3_cmd view-bucket my-bucket
    aws_s3_cmd view-object my-bucket path/to/file.txt

    # Clipboard operations
    aws_s3_cmd copy-bucket-arn my-bucket
    aws_s3_cmd copy-bucket-name my-bucket
    aws_s3_cmd copy-object-arn my-bucket path/to/file.txt
    aws_s3_cmd copy-object-key path/to/file.txt

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_s3_cmd {list-*|view-*|copy-*} [args]"
	gum log --level info "Run 'aws_s3_cmd --help' for more information"
	exit 1
	;;
esac
