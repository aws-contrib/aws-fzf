#!/usr/bin/env bats
#
# Tests for scripts/aws_sso_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_sso_cmd.sh"
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
	[[ "$output" =~ "aws fzf sso" ]]
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
# copy-profile-name
# ---------------------------------------------------------------------------

@test "copy-profile-name: fails when no profile name is provided" {
	run bash "$CMD" copy-profile-name
	[ "$status" -eq 1 ]
}

@test "copy-profile-name: copies the profile name to the clipboard" {
	run bash "$CMD" copy-profile-name "dev-account"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "dev-account" ]
}

# ---------------------------------------------------------------------------
# copy-account-id (reads from aws configure get)
# ---------------------------------------------------------------------------

@test "copy-account-id: fails when no profile name is provided" {
	run bash "$CMD" copy-account-id
	[ "$status" -eq 1 ]
}

@test "copy-account-id: copies the account ID to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
# Respond to: aws configure get sso_account_id --profile <profile>
echo "123456789012"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-account-id "dev-account"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "123456789012" ]
}

@test "copy-account-id: fails when the account ID cannot be retrieved" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-account-id "dev-account"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# login (delegates to aws sso login)
# ---------------------------------------------------------------------------

@test "login: fails when no profile name is provided" {
	run bash "$CMD" login
	[ "$status" -eq 1 ]
}

@test "login: succeeds when aws sso login returns zero" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
# Mock aws sso login: just exit 0
exit 0
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" login "dev-account"
	[ "$status" -eq 0 ]
}

@test "login: fails when aws sso login returns non-zero" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" login "dev-account"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# logout (delegates to aws sso logout)
# ---------------------------------------------------------------------------

@test "logout: fails when no profile name is provided" {
	run bash "$CMD" logout
	[ "$status" -eq 1 ]
}

@test "logout: succeeds when aws sso logout returns zero" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" logout "dev-account"
	[ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# open (opens console URL)
# ---------------------------------------------------------------------------

@test "open: fails when no profile name is provided" {
	run bash "$CMD" open
	[ "$status" -eq 1 ]
}

@test "open: opens the AWS SSO console page in the browser" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$3" in
  sso_start_url) echo "https://my-org.awsapps.com/start" ;;
  sso_account_id) echo "123456789012" ;;
  sso_role_name) echo "DeveloperAccess" ;;
  region) echo "us-east-1" ;;
  *) echo "" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" open "dev-account"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "awsapps.com" ]]
}

@test "open: fails when the sso_start_url is not configured" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" open "dev-account"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# list (parses ~/.aws/config via awk)
# ---------------------------------------------------------------------------

@test "list: prints a header row" {
	AWS_CONFIG_FILE="$FIXTURES/aws-config-sso.ini" \
		run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "PROFILE" ]]
}

@test "list: includes the SSO profile names in the output" {
	AWS_CONFIG_FILE="$FIXTURES/aws-config-sso.ini" \
		run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "dev-account" ]]
	[[ "$output" =~ "prod-account" ]]
}

@test "list: includes the account IDs in the output" {
	AWS_CONFIG_FILE="$FIXTURES/aws-config-sso.ini" \
		run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "123456789012" ]]
}
