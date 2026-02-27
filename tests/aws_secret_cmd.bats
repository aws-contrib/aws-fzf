#!/usr/bin/env bats
#
# Tests for scripts/aws_secret_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_secret_cmd.sh"
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
	[[ "$output" =~ "aws fzf secret" ]]
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

@test "copy-name: fails when no secret name is provided" {
	run bash "$CMD" copy-name
	[ "$status" -eq 1 ]
}

@test "copy-name: copies the secret name to the clipboard" {
	run bash "$CMD" copy-name "prod/db-password"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "prod/db-password" ]
}

# ---------------------------------------------------------------------------
# copy-arn (calls AWS API via gum spin)
# ---------------------------------------------------------------------------

@test "copy-arn: fails when no secret name is provided" {
	run bash "$CMD" copy-arn
	[ "$status" -eq 1 ]
}

@test "copy-arn: copies the Secrets Manager ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/db-password-AbCdEf"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-arn "prod/db-password"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:secretsmanager" ]]
}

@test "copy-arn: fails when AWS returns no result" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-arn "prod/db-password"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# copy-value (calls AWS API via gum spin)
# ---------------------------------------------------------------------------

@test "copy-value: fails when no secret name is provided" {
	run bash "$CMD" copy-value
	[ "$status" -eq 1 ]
}

@test "copy-value: copies the secret value to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo "super-secret-value-123"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-value "prod/db-password"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "super-secret-value-123" ]
}

# ---------------------------------------------------------------------------
# view-secret (opens URL)
# ---------------------------------------------------------------------------

@test "view-secret: fails when no secret name is provided" {
	run bash "$CMD" view-secret
	[ "$status" -eq 1 ]
}

@test "view-secret: opens the Secrets Manager console page in the browser" {
	run bash "$CMD" view-secret "prod/db-password"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "secretsmanager" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "prod" ]]
}

# ---------------------------------------------------------------------------
# list (calls AWS API, formats output)
# ---------------------------------------------------------------------------

@test "list: prints a header row" {
	make_aws_mock_fixture "aws-secret-list.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}

@test "list: includes the secret name in the output" {
	make_aws_mock_fixture "aws-secret-list.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "prod/db-password" ]]
}
