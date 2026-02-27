#!/usr/bin/env bats
#
# Tests for scripts/aws_log_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_log_cmd.sh"
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
	[[ "$output" =~ "aws fzf logs" ]]
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
# copy-group-name
# ---------------------------------------------------------------------------

@test "copy-group-name: fails when no log group name is provided" {
	run bash "$CMD" copy-group-name
	[ "$status" -eq 1 ]
}

@test "copy-group-name: copies the log group name to the clipboard" {
	run bash "$CMD" copy-group-name "/aws/lambda/my-function"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "/aws/lambda/my-function" ]
}

# ---------------------------------------------------------------------------
# copy-stream-name
# ---------------------------------------------------------------------------

@test "copy-stream-name: fails when no log stream name is provided" {
	run bash "$CMD" copy-stream-name
	[ "$status" -eq 1 ]
}

@test "copy-stream-name: copies the log stream name to the clipboard" {
	run bash "$CMD" copy-stream-name "2024/01/15/[\$LATEST]abc123"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "2024/01/15" ]]
}

# ---------------------------------------------------------------------------
# copy-group-arn (constructed from region + account)
# ---------------------------------------------------------------------------

@test "copy-group-arn: fails when no log group name is provided" {
	run bash "$CMD" copy-group-arn
	[ "$status" -eq 1 ]
}

@test "copy-group-arn: copies the CloudWatch Logs group ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "sts get-caller-identity") echo '{"Account":"123456789012"}' ;;
  "configure get") echo "us-east-1" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-group-arn "/aws/lambda/my-function"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:logs:" ]]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "log-group" ]]
}

# ---------------------------------------------------------------------------
# view-group (opens URL)
# ---------------------------------------------------------------------------

@test "view-group: fails when no log group name is provided" {
	run bash "$CMD" view-group
	[ "$status" -eq 1 ]
}

@test "view-group: opens the CloudWatch Logs console page in the browser" {
	run bash "$CMD" view-group "/aws/lambda/my-function"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "cloudwatch" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "log-group" ]]
}

# ---------------------------------------------------------------------------
# view-stream (opens URL)
# ---------------------------------------------------------------------------

@test "view-stream: fails when no arguments are provided" {
	run bash "$CMD" view-stream
	[ "$status" -eq 1 ]
}

@test "view-stream: fails when only the log group is provided" {
	run bash "$CMD" view-stream "/aws/lambda/my-function"
	[ "$status" -eq 1 ]
}

@test "view-stream: opens the CloudWatch log stream console page in the browser" {
	run bash "$CMD" view-stream "/aws/lambda/my-function" "2024/01/15/[\$LATEST]abc123"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "cloudwatch" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "log-events" ]]
}

# ---------------------------------------------------------------------------
# list-groups
# ---------------------------------------------------------------------------

@test "list-groups: prints a header row" {
	make_aws_mock_fixture "aws-log-groups.json"
	run bash "$CMD" list-groups
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}

@test "list-groups: includes the log group name in the output" {
	make_aws_mock_fixture "aws-log-groups.json"
	run bash "$CMD" list-groups
	[ "$status" -eq 0 ]
	[[ "$output" =~ "/aws/lambda/my-function" ]]
}

# ---------------------------------------------------------------------------
# list-streams
# ---------------------------------------------------------------------------

@test "list-streams: fails when no log group is provided" {
	run bash "$CMD" list-streams
	[ "$status" -eq 1 ]
}

@test "list-streams: prints a header row" {
	make_aws_mock_fixture "aws-log-streams.json"
	run bash "$CMD" list-streams "/aws/lambda/my-function"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}
