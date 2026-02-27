#!/usr/bin/env bats
#
# Tests for scripts/aws_param_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_param_cmd.sh"
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
	[[ "$output" =~ "aws fzf param" ]]
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

@test "copy-name: fails when no parameter name is provided" {
	run bash "$CMD" copy-name
	[ "$status" -eq 1 ]
}

@test "copy-name: copies the parameter name to the clipboard" {
	run bash "$CMD" copy-name "/app/db/password"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "/app/db/password" ]
}

# ---------------------------------------------------------------------------
# copy-arn (constructed from region + account)
# ---------------------------------------------------------------------------

@test "copy-arn: fails when no parameter name is provided" {
	run bash "$CMD" copy-arn
	[ "$status" -eq 1 ]
}

@test "copy-arn: copies the SSM Parameter Store ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "sts get-caller-identity") echo '{"Account":"123456789012"}' ;;
  "configure get") echo "us-east-1" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-arn "/app/db/password"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:ssm:" ]]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "parameter/app/db/password" ]]
}

# ---------------------------------------------------------------------------
# view-parameter (opens URL)
# ---------------------------------------------------------------------------

@test "view-parameter: fails when no parameter name is provided" {
	run bash "$CMD" view-parameter
	[ "$status" -eq 1 ]
}

@test "view-parameter: opens the Systems Manager console page in the browser" {
	run bash "$CMD" view-parameter "/app/db/password"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "systems-manager" ]]
}

# ---------------------------------------------------------------------------
# copy-value
# ---------------------------------------------------------------------------

@test "copy-value: fails when no parameter name is provided" {
	run bash "$CMD" copy-value
	[ "$status" -eq 1 ]
}

@test "copy-value: copies the parameter value to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "ssm describe-parameters") echo '{"Parameters":[{"Type":"String"}]}' ;;
  "ssm get-parameter") echo "my-param-value" ;;
  *) echo "my-param-value" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-value "/app/db/password"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-param-value" ]
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

@test "list: prints a header row" {
	make_aws_mock_fixture "aws-param-list.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}

@test "list: includes the parameter name in the output" {
	make_aws_mock_fixture "aws-param-list.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "/app/db/password" ]]
}
