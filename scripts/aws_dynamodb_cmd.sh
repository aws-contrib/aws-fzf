#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

# aws_dynamodb_cmd - Utility helper for DynamoDB operations
#
# This executable handles DynamoDB console viewing.
# Designed to be called from fzf keybindings and other scripts.
#
# USAGE:
#   aws_dynamodb_cmd view-table <table-name>
#
# DESCRIPTION:
#   Provides console viewing functionality for DynamoDB tables.

# Source shared core utilities
_aws_dynamodb_cmd_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=scripts/aws_core.sh
source "$_aws_dynamodb_cmd_source_dir/aws_core.sh"

# _aws_dynamodb_view_table()
#
# Open DynamoDB table in AWS Console
#
# PARAMETERS:
#   $1 - Table name (required)
#
# DESCRIPTION:
#   Opens the specified DynamoDB table in the default web browser
#   via the AWS Console URL
#
_aws_dynamodb_view_table() {
	local table="${1:-}"

	if [ -z "$table" ]; then
		gum log --level error "Table name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/dynamodbv2/home?region=${region}#table?name=${table}"
}

# _aws_dynamodb_view_items()
#
# Open DynamoDB table items explorer in AWS Console
#
# PARAMETERS:
#   $1 - Table name (required)
#
# DESCRIPTION:
#   Opens the items explorer page for the specified DynamoDB table
#   in the default web browser via the AWS Console URL
#
_aws_dynamodb_view_items() {
	local table="${1:-}"

	if [ -z "$table" ]; then
		gum log --level error "Table name is required"
		exit 1
	fi

	local region
	region=$(_get_aws_region)

	_open_url "https://${region}.console.aws.amazon.com/dynamodbv2/home?region=${region}#item-explorer?operation=SCAN&table=${table}"
}

# _aws_dynamodb_copy_arn()
#
# Copy table ARN to clipboard
#
# PARAMETERS:
#   $1 - Table name (required)
#
# DESCRIPTION:
#   Constructs the table ARN and copies it to the clipboard
#
_aws_dynamodb_copy_arn() {
	local table="${1:-}"

	if [ -z "$table" ]; then
		gum log --level error "Table name is required"
		exit 1
	fi

	local region account_id
	region=$(_get_aws_region)
	account_id=$(
		gum spin --title "Getting AWS Caller Identity..." -- \
			aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
	)

	local arn="arn:aws:dynamodb:${region}:${account_id}:table/${table}"
	_copy_to_clipboard "$arn" "table ARN"
}

# _aws_dynamodb_copy_name()
#
# Copy table name to clipboard
#
# PARAMETERS:
#   $1 - Table name (required)
#
# DESCRIPTION:
#   Copies the table name to the clipboard
#
_aws_dynamodb_copy_name() {
	local table="${1:-}"

	if [ -z "$table" ]; then
		gum log --level error "Table name is required"
		exit 1
	fi

	_copy_to_clipboard "$table" "table name"
}

# _aws_dynamodb_help_interactive()
#
# Display interactive help for DynamoDB commands
#
# DESCRIPTION:
#   Shows keyboard shortcuts and available actions in a formatted help panel
#   using gum format with markdown. Designed to be used in fzf preview window.
#
_aws_dynamodb_help_interactive() {
	gum format <<'EOF'
# Help

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **`ctrl-r`** | Reload list |
| **`enter`** | View details |
| **`ctrl-o`** | Open overview |
| **`ctrl-O`** | Open items (scan) |
| **`alt-a`** | Copy ARN |
| **`alt-n`** | Copy name |
| **`alt-h`** | Toggle help |
| **`ESC`** | Exit |
EOF
}

# _aws_dynamodb_table_list_cmd()
#
# Fetch and format DynamoDB tables for fzf display
#
# PARAMETERS:
#   $@ - AWS CLI arguments (--region, --profile, etc.)
#
# OUTPUT:
#   Tab-separated formatted list with header
#
# DESCRIPTION:
#   Performs AWS API call to list DynamoDB tables and formats output
#   for fzf consumption. Can be called as standalone script.
#
_aws_dynamodb_table_list_cmd() {
	local list_args=("$@")

	# Define jq formatting
	local table_list_jq='(["TABLE NAME"] | @tsv),
	                     (.TableNames[] | [.] | @tsv)'

	# Fetch and format DynamoDB tables (without gum spin - caller handles that)
	aws dynamodb list-tables "${list_args[@]}" --output json |
		jq -r "$table_list_jq" | column -t -s $'\t'
}

# Command router
case "${1:-}" in
list)
	shift
	_aws_dynamodb_table_list_cmd "$@"
	;;
help)
	_aws_dynamodb_help_interactive
	;;
view-table)
	shift
	_aws_dynamodb_view_table "$@"
	;;
view-items)
	shift
	_aws_dynamodb_view_items "$@"
	;;
copy-arn)
	shift
	_aws_dynamodb_copy_arn "$@"
	;;
copy-name)
	shift
	_aws_dynamodb_copy_name "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_dynamodb_cmd - Utility commands for DynamoDB operations

LISTING:
    aws_dynamodb_cmd list [aws-cli-args]

CONSOLE VIEWS:
    aws_dynamodb_cmd view-table <table-name>
    aws_dynamodb_cmd view-items <table-name>

CLIPBOARD OPERATIONS:
    aws_dynamodb_cmd copy-arn <table-name>
    aws_dynamodb_cmd copy-name <table-name>

DESCRIPTION:
    list: Fetches and formats DynamoDB tables for fzf display.
    View commands open DynamoDB resources in the AWS Console via the default browser.
    Clipboard commands copy resource identifiers to the system clipboard.

    view-table: Opens the table overview page (schema, indexes, metrics)
    view-items: Opens the items explorer page (browse, query, scan data)
    copy-arn:   Copies the table ARN to clipboard
    copy-name:  Copies the table name to clipboard

EXAMPLES:
    # List tables (for fzf reload)
    aws_dynamodb_cmd list --region us-east-1

    # Console views
    aws_dynamodb_cmd view-table my-table
    aws_dynamodb_cmd view-items my-table

    # Clipboard operations
    aws_dynamodb_cmd copy-arn my-table
    aws_dynamodb_cmd copy-name my-table

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_dynamodb_cmd {list|view-table|view-items|copy-arn|copy-name} [args]"
	gum log --level info "Run 'aws_dynamodb_cmd --help' for more information"
	exit 1
	;;
esac
