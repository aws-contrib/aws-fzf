#!/usr/bin/env bats
#
# Tests for scripts/aws_lambda_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_lambda_cmd.sh"
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
	[[ "$output" =~ "aws fzf lambda" ]]
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

@test "copy-name: fails when no function name is provided" {
	run bash "$CMD" copy-name
	[ "$status" -eq 1 ]
}

@test "copy-name: copies the function name to the clipboard" {
	run bash "$CMD" copy-name "my-function"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-function" ]
}

# ---------------------------------------------------------------------------
# copy-arn (fetches via AWS API)
# ---------------------------------------------------------------------------

@test "copy-arn: fails when no function name is provided" {
	run bash "$CMD" copy-arn
	[ "$status" -eq 1 ]
}

@test "copy-arn: copies the Lambda function ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo "arn:aws:lambda:us-east-1:123456789012:function:my-function"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-arn "my-function"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:lambda" ]]
}

@test "copy-arn: fails when AWS returns no result" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-arn "my-function"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# view-function (opens URL)
# ---------------------------------------------------------------------------

@test "view-function: fails when no function name is provided" {
	run bash "$CMD" view-function
	[ "$status" -eq 1 ]
}

@test "view-function: opens the Lambda console page in the browser" {
	run bash "$CMD" view-function "my-function"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "lambda" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "my-function" ]]
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

@test "list: prints a header row" {
	make_aws_mock_fixture "aws-lambda-list.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}

@test "list: includes the function name in the output" {
	make_aws_mock_fixture "aws-lambda-list.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "my-function" ]]
}
