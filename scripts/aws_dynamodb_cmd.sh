#!/usr/bin/env bash

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

set -euo pipefail

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

# Command router
case "${1:-}" in
view-table)
	shift
	_aws_dynamodb_view_table "$@"
	;;
view-items)
	shift
	_aws_dynamodb_view_items "$@"
	;;
--help | -h | help | "")
	cat <<'EOF'
aws_dynamodb_cmd - Utility commands for DynamoDB operations

CONSOLE VIEWS:
    aws_dynamodb_cmd view-table <table-name>
    aws_dynamodb_cmd view-items <table-name>

DESCRIPTION:
    View commands open DynamoDB resources in the AWS Console via the default browser.

    view-table: Opens the table overview page (schema, indexes, metrics)
    view-items: Opens the items explorer page (browse, query, scan data)

EXAMPLES:
    # Console views
    aws_dynamodb_cmd view-table my-table
    aws_dynamodb_cmd view-items my-table

EOF
	;;
*)
	gum log --level error "Unknown subcommand '${1:-}'"
	gum log --level info "Usage: aws_dynamodb_cmd {view-table|view-items} [args]"
	gum log --level info "Run 'aws_dynamodb_cmd --help' for more information"
	exit 1
	;;
esac
