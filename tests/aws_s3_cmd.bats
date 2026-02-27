#!/usr/bin/env bats
#
# Tests for scripts/aws_s3_cmd.sh

setup() {
	load 'test_helper/common'
	setup_mock_bin
	CMD="$PROJECT_ROOT/scripts/aws_s3_cmd.sh"
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
	[[ "$output" =~ "aws fzf s3" ]]
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
# copy-bucket-name
# ---------------------------------------------------------------------------

@test "copy-bucket-name: fails when no bucket name is provided" {
	run bash "$CMD" copy-bucket-name
	[ "$status" -eq 1 ]
}

@test "copy-bucket-name: copies the bucket name to the clipboard" {
	run bash "$CMD" copy-bucket-name "my-app-data"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "my-app-data" ]
}

# ---------------------------------------------------------------------------
# copy-bucket-arn (constructed locally)
# ---------------------------------------------------------------------------

@test "copy-bucket-arn: fails when no bucket name is provided" {
	run bash "$CMD" copy-bucket-arn
	[ "$status" -eq 1 ]
}

@test "copy-bucket-arn: copies the S3 bucket ARN to the clipboard" {
	run bash "$CMD" copy-bucket-arn "my-app-data"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "arn:aws:s3:::my-app-data" ]
}

# ---------------------------------------------------------------------------
# copy-object-key
# ---------------------------------------------------------------------------

@test "copy-object-key: fails when no object key is provided" {
	run bash "$CMD" copy-object-key
	[ "$status" -eq 1 ]
}

@test "copy-object-key: copies the object key to the clipboard" {
	run bash "$CMD" copy-object-key "logs/2024/01/app.log"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "logs/2024/01/app.log" ]
}

# ---------------------------------------------------------------------------
# copy-object-arn
# ---------------------------------------------------------------------------

@test "copy-object-arn: fails when no arguments are provided" {
	run bash "$CMD" copy-object-arn
	[ "$status" -eq 1 ]
}

@test "copy-object-arn: fails when only the bucket name is provided" {
	run bash "$CMD" copy-object-arn "my-app-data"
	[ "$status" -eq 1 ]
}

@test "copy-object-arn: copies the S3 object ARN to the clipboard" {
	run bash "$CMD" copy-object-arn "my-app-data" "logs/2024/01/app.log"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "arn:aws:s3:::my-app-data/logs/2024/01/app.log" ]
}

# ---------------------------------------------------------------------------
# view-bucket (opens URL)
# ---------------------------------------------------------------------------

@test "view-bucket: fails when no bucket name is provided" {
	run bash "$CMD" view-bucket
	[ "$status" -eq 1 ]
}

@test "view-bucket: opens the S3 bucket console page in the browser" {
	run bash "$CMD" view-bucket "my-app-data"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "s3.console" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "my-app-data" ]]
}

# ---------------------------------------------------------------------------
# view-object (opens URL)
# ---------------------------------------------------------------------------

@test "view-object: fails when no arguments are provided" {
	run bash "$CMD" view-object
	[ "$status" -eq 1 ]
}

@test "view-object: fails when only the bucket name is provided" {
	run bash "$CMD" view-object "my-app-data"
	[ "$status" -eq 1 ]
}

@test "view-object: opens the S3 object console page in the browser" {
	run bash "$CMD" view-object "my-app-data" "logs/2024/01/app.log"
	[ "$status" -eq 0 ]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "s3.console" ]]
	[[ "$(cat "$MOCK_URL_FILE")" =~ "object" ]]
}

# ---------------------------------------------------------------------------
# list-buckets
# ---------------------------------------------------------------------------

@test "list-buckets: prints a header row" {
	make_aws_mock_fixture "aws-s3-buckets.json"
	run bash "$CMD" list-buckets
	[ "$status" -eq 0 ]
	[[ "$output" =~ "NAME" ]]
}

@test "list-buckets: includes the bucket name in the output" {
	make_aws_mock_fixture "aws-s3-buckets.json"
	run bash "$CMD" list-buckets
	[ "$status" -eq 0 ]
	[[ "$output" =~ "my-app-data" ]]
}

# ---------------------------------------------------------------------------
# list-objects
# ---------------------------------------------------------------------------

@test "list-objects: fails when no bucket name is provided" {
	run bash "$CMD" list-objects
	[ "$status" -eq 1 ]
}

@test "list-objects: prints a header row" {
	make_aws_mock_fixture "aws-s3-objects.json"
	run bash "$CMD" list-objects "my-app-data"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "KEY" ]]
}

@test "list-objects: includes the object key in the output" {
	make_aws_mock_fixture "aws-s3-objects.json"
	run bash "$CMD" list-objects "my-app-data"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "logs/2024/01/app.log" ]]
}
