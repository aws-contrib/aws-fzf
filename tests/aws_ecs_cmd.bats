#!/usr/bin/env bats
#
# Tests for scripts/aws_ecs_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_ecs_cmd.sh"
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
	[[ "$output" =~ "aws fzf ecs" ]]
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

@test "copy-cluster-name: fails when no cluster name is provided" {
	run bash "$CMD" copy-cluster-name
	[ "$status" -eq 1 ]
}

@test "copy-cluster-name: copies the cluster name to the clipboard" {
	run bash "$CMD" copy-cluster-name "my-cluster"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-cluster" ]
}

# ---------------------------------------------------------------------------
# copy-cluster-arn (constructed from region + account)
# ---------------------------------------------------------------------------

@test "copy-cluster-arn: fails when no cluster name is provided" {
	run bash "$CMD" copy-cluster-arn
	[ "$status" -eq 1 ]
}

@test "copy-cluster-arn: copies the ECS cluster ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "sts get-caller-identity") echo '{"Account":"123456789012"}' ;;
  "configure get") echo "us-east-1" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-cluster-arn "my-cluster"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:ecs:" ]]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "cluster/my-cluster" ]]
}

# ---------------------------------------------------------------------------
# copy-service-name
# ---------------------------------------------------------------------------

@test "copy-service-name: fails when no service name is provided" {
	run bash "$CMD" copy-service-name
	[ "$status" -eq 1 ]
}

@test "copy-service-name: copies the service name to the clipboard" {
	run bash "$CMD" copy-service-name "my-service"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-service" ]
}

# ---------------------------------------------------------------------------
# copy-service-arn
# ---------------------------------------------------------------------------

@test "copy-service-arn: fails when no arguments are provided" {
	run bash "$CMD" copy-service-arn
	[ "$status" -eq 1 ]
}

@test "copy-service-arn: fails when only the cluster name is provided" {
	run bash "$CMD" copy-service-arn "my-cluster"
	[ "$status" -eq 1 ]
}

@test "copy-service-arn: copies the ECS service ARN to the clipboard" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "sts get-caller-identity") echo '{"Account":"123456789012"}' ;;
  "configure get") echo "us-east-1" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" copy-service-arn "my-cluster" "my-service"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:ecs:" ]]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "service/my-cluster/my-service" ]]
}

# ---------------------------------------------------------------------------
# copy-task-arn
# ---------------------------------------------------------------------------

@test "copy-task-arn: fails when no task ARN is provided" {
	run bash "$CMD" copy-task-arn
	[ "$status" -eq 1 ]
}

@test "copy-task-arn: copies the task ARN to the clipboard" {
	local task_arn="arn:aws:ecs:us-east-1:123456789012:task/my-cluster/abc123"
	run bash "$CMD" copy-task-arn "$task_arn"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_CLIPBOARD")" =~ "arn:aws:ecs" ]]
}

# ---------------------------------------------------------------------------
# view-cluster (opens URL)
# ---------------------------------------------------------------------------

@test "view-cluster: fails when no cluster name is provided" {
	run bash "$CMD" view-cluster
	[ "$status" -eq 1 ]
}

@test "view-cluster: opens the ECS cluster console page in the browser" {
	run bash "$CMD" view-cluster "my-cluster"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "ecs" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "my-cluster" ]]
}

# ---------------------------------------------------------------------------
# view-service (opens URL)
# ---------------------------------------------------------------------------

@test "view-service: fails when no arguments are provided" {
	run bash "$CMD" view-service
	[ "$status" -eq 1 ]
}

@test "view-service: fails when only the cluster name is provided" {
	run bash "$CMD" view-service "my-cluster"
	[ "$status" -eq 1 ]
}

@test "view-service: opens the ECS service console page in the browser" {
	run bash "$CMD" view-service "my-cluster" "my-service"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "ecs" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "my-service" ]]
}

# ---------------------------------------------------------------------------
# list-clusters
# ---------------------------------------------------------------------------

@test "list-clusters: prints a header row" {
	# Mock aws to handle both list-clusters and describe-clusters
	cat > "$MOCK_BIN/aws" << MOCK
#!/usr/bin/env bash
case "\$1 \$2" in
  "ecs list-clusters") cat "$FIXTURES/aws-ecs-list-clusters.json" ;;
  "ecs describe-clusters") cat "$FIXTURES/aws-ecs-describe-clusters.json" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" list-clusters
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}

@test "list-clusters: includes the cluster name in the output" {
	cat > "$MOCK_BIN/aws" << MOCK
#!/usr/bin/env bash
case "\$1 \$2" in
  "ecs list-clusters") cat "$FIXTURES/aws-ecs-list-clusters.json" ;;
  "ecs describe-clusters") cat "$FIXTURES/aws-ecs-describe-clusters.json" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" list-clusters
	[ "$status" -eq 0 ]
	[[ "$output" =~ "my-cluster" ]]
}

# ---------------------------------------------------------------------------
# list-services
# ---------------------------------------------------------------------------

@test "list-services: fails when no cluster name is provided" {
	run bash "$CMD" list-services
	[ "$status" -eq 1 ]
}

@test "list-services: prints a header row" {
	cat > "$MOCK_BIN/aws" << MOCK
#!/usr/bin/env bash
case "\$1 \$2" in
  "ecs list-services") cat "$FIXTURES/aws-ecs-list-services.json" ;;
  "ecs describe-services") cat "$FIXTURES/aws-ecs-describe-services.json" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash "$CMD" list-services "my-cluster"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}
