#!/usr/bin/env bats
#
# Tests for scripts/aws_rds_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_rds_cmd.sh"
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
	[[ "$output" =~ "aws fzf rds" ]]
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
# copy-instance-name
# ---------------------------------------------------------------------------

@test "copy-instance-name: fails when no instance identifier is provided" {
	run bash "$CMD" copy-instance-name
	[ "$status" -eq 1 ]
}

@test "copy-instance-name: copies the instance identifier to the clipboard" {
	run bash "$CMD" copy-instance-name "my-postgres-db"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-postgres-db" ]
}

# ---------------------------------------------------------------------------
# copy-cluster-name
# ---------------------------------------------------------------------------

@test "copy-cluster-name: fails when no cluster identifier is provided" {
	run bash "$CMD" copy-cluster-name
	[ "$status" -eq 1 ]
}

@test "copy-cluster-name: copies the cluster identifier to the clipboard" {
	run bash "$CMD" copy-cluster-name "my-aurora-cluster"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-aurora-cluster" ]
}

# ---------------------------------------------------------------------------
# copy-instance-arn (fetches via AWS API)
# ---------------------------------------------------------------------------

@test "copy-instance-arn: fails when no instance identifier is provided" {
	run bash "$CMD" copy-instance-arn
	[ "$status" -eq 1 ]
}

@test "copy-instance-arn: copies the RDS instance ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo "arn:aws:rds:us-east-1:123456789012:db:my-postgres-db"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-instance-arn "my-postgres-db"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:rds" ]]
}

@test "copy-instance-arn: fails when AWS returns no result" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-instance-arn "my-postgres-db"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# copy-cluster-arn (fetches via AWS API)
# ---------------------------------------------------------------------------

@test "copy-cluster-arn: fails when no cluster identifier is provided" {
	run bash "$CMD" copy-cluster-arn
	[ "$status" -eq 1 ]
}

@test "copy-cluster-arn: copies the Aurora cluster ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo "arn:aws:rds:us-east-1:123456789012:cluster:my-aurora-cluster"
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-cluster-arn "my-aurora-cluster"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:rds" ]]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "cluster" ]]
}

# ---------------------------------------------------------------------------
# view-instance (opens URL)
# ---------------------------------------------------------------------------

@test "view-instance: fails when no instance identifier is provided" {
	run bash "$CMD" view-instance
	[ "$status" -eq 1 ]
}

@test "view-instance: opens the RDS instance console page in the browser" {
	run bash "$CMD" view-instance "my-postgres-db"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "rds" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "my-postgres-db" ]]
}

# ---------------------------------------------------------------------------
# view-cluster (opens URL)
# ---------------------------------------------------------------------------

@test "view-cluster: fails when no cluster identifier is provided" {
	run bash "$CMD" view-cluster
	[ "$status" -eq 1 ]
}

@test "view-cluster: opens the RDS cluster console page in the browser" {
	run bash "$CMD" view-cluster "my-aurora-cluster"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "rds" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "my-aurora-cluster" ]]
}

# ---------------------------------------------------------------------------
# connect-instance / connect-cluster require psql — test early-exit paths
# ---------------------------------------------------------------------------

@test "connect-instance: fails when no instance identifier is provided" {
	run bash "$CMD" connect-instance
	[ "$status" -eq 1 ]
}

@test "connect-cluster: fails when no cluster identifier is provided" {
	run bash "$CMD" connect-cluster
	[ "$status" -eq 1 ]
}

@test "connect-instance: fails when AWS returns no instance information" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
echo ""
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" connect-instance "my-postgres-db"
	[ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# list-instances
# ---------------------------------------------------------------------------

@test "list-instances: prints a header row" {
	make_aws_mock_fixture "aws-rds-instances.json"
	run bash "$CMD" list-instances
	[ "$status" -eq 0 ]
	[[ "$output" =~ "ID" ]]
}

@test "list-instances: includes the instance identifier in the output" {
	make_aws_mock_fixture "aws-rds-instances.json"
	run bash "$CMD" list-instances
	[ "$status" -eq 0 ]
	[[ "$output" =~ "my-postgres-db" ]]
}

# ---------------------------------------------------------------------------
# list-clusters
# ---------------------------------------------------------------------------

@test "list-clusters: prints a header row" {
	make_aws_mock_fixture "aws-rds-clusters.json"
	run bash "$CMD" list-clusters
	[ "$status" -eq 0 ]
	[[ "$output" =~ "ID" ]]
}

@test "list-clusters: includes the cluster identifier in the output" {
	make_aws_mock_fixture "aws-rds-clusters.json"
	run bash "$CMD" list-clusters
	[ "$status" -eq 0 ]
	[[ "$output" =~ "my-aurora-cluster" ]]
}
