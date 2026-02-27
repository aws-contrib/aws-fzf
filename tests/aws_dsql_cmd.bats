#!/usr/bin/env bats
#
# Tests for scripts/aws_dsql_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_dsql_cmd.sh"
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
	[[ "$output" =~ "aws fzf dsql" ]]
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
# copy-cluster-name
# ---------------------------------------------------------------------------

@test "copy-cluster-name: fails when no cluster identifier is provided" {
	run bash "$CMD" copy-cluster-name
	[ "$status" -eq 1 ]
}

@test "copy-cluster-name: copies the cluster identifier to the clipboard" {
	run bash "$CMD" copy-cluster-name "abc123xyz"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "abc123xyz" ]
}

# ---------------------------------------------------------------------------
# copy-cluster-arn (fetches via AWS API)
# ---------------------------------------------------------------------------

@test "copy-cluster-arn: fails when no cluster identifier is provided" {
	run bash "$CMD" copy-cluster-arn
	[ "$status" -eq 1 ]
}

@test "copy-cluster-arn: copies the DSQL cluster ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo "arn:aws:dsql:us-east-1:123456789012:cluster/abc123xyz"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-cluster-arn "abc123xyz"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:dsql" ]]
}

@test "copy-cluster-arn: fails when AWS returns no result" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-cluster-arn "abc123xyz"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# view-cluster (opens URL)
# ---------------------------------------------------------------------------

@test "view-cluster: fails when no cluster identifier is provided" {
	run bash "$CMD" view-cluster
	[ "$status" -eq 1 ]
}

@test "view-cluster: opens the Aurora DSQL console page in the browser" {
	run bash "$CMD" view-cluster "abc123xyz"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "dsql" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "abc123xyz" ]]
}

# ---------------------------------------------------------------------------
# connect-cluster — test early-exit paths (no psql mock)
# ---------------------------------------------------------------------------

@test "connect-cluster: fails when no cluster identifier is provided" {
	run bash "$CMD" connect-cluster
	[ "$status" -eq 1 ]
}

@test "connect-cluster: fails when AWS returns no cluster information" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" connect-cluster "abc123xyz"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# list
# ---------------------------------------------------------------------------

@test "list: prints a header row" {
	make_aws_mock_fixture "aws-dsql-clusters.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "IDENTIFIER" ]]
}

@test "list: includes the cluster identifier in the output" {
	make_aws_mock_fixture "aws-dsql-clusters.json"
	run bash "$CMD" list
	[ "$status" -eq 0 ]
	[[ "$output" =~ "abc123xyz" ]]
}
