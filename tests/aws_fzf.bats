#!/usr/bin/env bats
#
# Tests for the aws-fzf main entry point
#
# These tests only cover the routing and output logic that exits before
# launching an interactive fzf session. All dependencies (aws, fzf, jq, gum)
# are mocked in MOCK_BIN.

setup() {
	load 'test_helper/common'
	setup_mock_bin
}

teardown() {
	teardown_mock_bin
}

# Helper: run aws-fzf with the mock bin in PATH
run_aws_fzf() {
	run bash "$PROJECT_ROOT/aws-fzf" "$@"
}

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

@test "prints usage when called with no arguments" {
	run_aws_fzf
	[ "$status" -eq 0 ]
	[[ "$output" =~ "aws fzf" ]]
}

@test "prints usage for --help" {
	run_aws_fzf --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "USAGE" ]]
}

@test "prints usage for -h" {
	run_aws_fzf -h
	[ "$status" -eq 0 ]
	[[ "$output" =~ "USAGE" ]]
}

@test "prints usage for the help subcommand" {
	run_aws_fzf help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "COMMANDS" ]]
}

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------

@test "prints the version number for --version" {
	run_aws_fzf --version
	[ "$status" -eq 0 ]
	[[ "$output" =~ "0.2.0" ]]
}

@test "prints the version number for -V" {
	run_aws_fzf -V
	[ "$status" -eq 0 ]
	[[ "$output" =~ "0.2.0" ]]
}

# ---------------------------------------------------------------------------
# Unrecognized argument (treated as fzf flag, no service → shows help)
# ---------------------------------------------------------------------------

@test "prints usage when an unrecognised flag is passed without a service" {
	run_aws_fzf --unknown-flag-xyz
	[ "$status" -eq 0 ]
	[[ "$output" =~ "aws fzf" ]]
}

# ---------------------------------------------------------------------------
# Help text content
# ---------------------------------------------------------------------------

@test "lists all available services in the usage output" {
	run_aws_fzf --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "secret" ]]
	[[ "$output" =~ "lambda" ]]
	[[ "$output" =~ "s3" ]]
	[[ "$output" =~ "ecs" ]]
	[[ "$output" =~ "dynamodb" ]]
}

@test "lists all required dependencies in the usage output" {
	run_aws_fzf --help
	[ "$status" -eq 0 ]
	[[ "$output" =~ "fzf" ]]
	[[ "$output" =~ "jq" ]]
	[[ "$output" =~ "gum" ]]
}
