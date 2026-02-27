#!/usr/bin/env bats
#
# Tests for scripts/aws_dynamodb_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_dynamodb_cmd.sh"
}

teardown() {
	teardown_mock_bin
}

# ---------------------------------------------------------------------------
# Help / routing
# ---------------------------------------------------------------------------

@test "prints usage when called with no arguments" {
	run bash "$CMD"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "aws fzf dynamodb" ]]
}

@test "prints usage for --help" {
	run bash "$CMD" --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "LISTING" ]]
}

@test "prints usage for -h" {
	run bash "$CMD" -h
	[ "$status" -eq 0 ]
}

@test "prints usage for the help subcommand" {
	run bash "$CMD" help
	[ "$status" -eq 0 ]
}

@test "fails for an unrecognised subcommand" {
	run bash "$CMD" unknown-cmd
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# copy-name
# ---------------------------------------------------------------------------

@test "copy-name: fails when no table name is provided" {
	run bash "$CMD" copy-name
	[ "$status" -eq 1 ]
}

@test "copy-name: copies the table name to the clipboard" {
	run bash "$CMD" copy-name "orders-table"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "orders-table" ]
}

# ---------------------------------------------------------------------------
# copy-arn (constructed from region + account)
# ---------------------------------------------------------------------------

@test "copy-arn: fails when no table name is provided" {
	run bash "$CMD" copy-arn
	[ "$status" -eq 1 ]
}

@test "copy-arn: copies the DynamoDB table ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "sts get-caller-identity") echo '{\"Account\":\"123456789012\"}' ;;
  "configure get") echo "us-east-1" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-arn "orders-table"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:dynamodb:" ]]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "table/orders-table" ]]
}

# ---------------------------------------------------------------------------
# view-table (opens overview URL)
# ---------------------------------------------------------------------------

@test "view-table: fails when no table name is provided" {
	run bash "$CMD" view-table
	[ "$status" -eq 1 ]
}

@test "view-table: opens the DynamoDB table overview console page in the browser" {
	run bash "$CMD" view-table "orders-table"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "dynamodb" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "orders-table" ]]
}

# ---------------------------------------------------------------------------
# view-items (opens item explorer URL)
# ---------------------------------------------------------------------------

@test "view-items: fails when no table name is provided" {
	run bash "$CMD" view-items
	[ "$status" -eq 1 ]
}

@test "view-items: opens the DynamoDB item explorer console page in the browser" {
	run bash "$CMD" view-items "orders-table"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "dynamodb" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "item-explorer" ]]
}

@test "view-table and view-items: open different console pages" {
	run bash "$CMD" view-table "orders-table"
	table_url="$(cat "$MOCK_URL_FILE")"

	run bash "$CMD" view-items "orders-table"
	items_url="$(cat "$MOCK_URL_FILE")"

	# URLs should differ
	[ "$table_url" != "$items_url" ]
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

@test "list: prints a header row" {
	make_aws_mock_fixture "aws-dynamodb-tables.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "TABLE NAME" ]]
}

@test "list: includes the table names in the output" {
	make_aws_mock_fixture "aws-dynamodb-tables.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "orders-table" ]]
	[[ "$output" =~ "users-table" ]]
}
