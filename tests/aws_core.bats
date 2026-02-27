#!/usr/bin/env bats
#
# Tests for scripts/aws_core.sh
#
# Each test runs aws_core.sh functions in a subprocess via `bash -c` to avoid
# the set -euo pipefail in the sourced file from affecting the test harness.

bats_require_minimum_version 1.5.0

setup() {
	load 'test_helper/common'
	setup_mock_bin
}

teardown() {
	teardown_mock_bin
}

# ---------------------------------------------------------------------------
# _parse_duration
# ---------------------------------------------------------------------------

@test "_parse_duration: converts 30s to 30 seconds" {
	run bash -c "source '$PROJECT_ROOT/scripts/aws_core.sh'; _parse_duration 30s"
	[ "$status" -eq 0 ]
	[ "$output" = "30" ]
}

@test "_parse_duration: converts 5m to 300 seconds" {
	run bash -c "source '$PROJECT_ROOT/scripts/aws_core.sh'; _parse_duration 5m"
	[ "$status" -eq 0 ]
	[ "$output" = "300" ]
}

@test "_parse_duration: converts 2h to 7200 seconds" {
	run bash -c "source '$PROJECT_ROOT/scripts/aws_core.sh'; _parse_duration 2h"
	[ "$status" -eq 0 ]
	[ "$output" = "7200" ]
}

@test "_parse_duration: converts 1d to 86400 seconds" {
	run bash -c "source '$PROJECT_ROOT/scripts/aws_core.sh'; _parse_duration 1d"
	[ "$status" -eq 0 ]
	[ "$output" = "86400" ]
}

@test "_parse_duration: fails for an unrecognised unit suffix" {
	run bash -c "source '$PROJECT_ROOT/scripts/aws_core.sh'; _parse_duration 5x; echo 'should not reach'"
	[ "$status" -ne 0 ]
}

@test "_parse_duration: fails when no unit suffix is provided" {
	run bash -c "source '$PROJECT_ROOT/scripts/aws_core.sh'; _parse_duration 42; echo 'should not reach'"
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# _get_aws_region
# ---------------------------------------------------------------------------

@test "_get_aws_region: returns the value of AWS_REGION when set" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		AWS_REGION=us-west-2
		_get_aws_region
	"
	[ "$status" -eq 0 ]
	[ "$output" = "us-west-2" ]
}

@test "_get_aws_region: falls back to AWS_DEFAULT_REGION when AWS_REGION is unset" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		unset AWS_REGION
		AWS_DEFAULT_REGION=eu-west-1
		_get_aws_region
	"
	[ "$status" -eq 0 ]
	[ "$output" = "eu-west-1" ]
}

@test "_get_aws_region: falls back to aws configure when both env vars are unset" {
	# Mock aws to return ap-southeast-1 for configure get region
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
if [[ "$1 $2 $3" == "configure get region" ]]; then
  echo "ap-southeast-1"
else
  echo "{}"
fi
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash -c "
		export PATH='$MOCK_BIN:$PATH'
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		unset AWS_REGION
		unset AWS_DEFAULT_REGION
		_get_aws_region
	"
	[ "$status" -eq 0 ]
	[ "$output" = "ap-southeast-1" ]
}

# ---------------------------------------------------------------------------
# _aws_fzf_options
# ---------------------------------------------------------------------------

@test "_aws_fzf_options: includes --ansi in the default options" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		_aws_fzf_options
		printf '%s\n' \"\${_fzf_options[@]}\" | grep -q -- '--ansi'
	"
	[ "$status" -eq 0 ]
}

@test "_aws_fzf_options: includes --layout in the default options" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		_aws_fzf_options
		printf '%s\n' \"\${_fzf_options[@]}\" | grep -q -- '--layout'
	"
	[ "$status" -eq 0 ]
}

@test "_aws_fzf_options: appends FZF_AWS_FLAGS when set" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		export FZF_AWS_FLAGS='--height 50%'
		_aws_fzf_options
		printf '%s\n' \"\${_fzf_options[@]}\" | grep -q -- '--height'
	"
	[ "$status" -eq 0 ]
}

@test "_aws_fzf_options: appends FZF_AWS_SECRET_OPTS for the SECRET command" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		export FZF_AWS_SECRET_OPTS='--border rounded'
		_aws_fzf_options SECRET
		printf '%s\n' \"\${_fzf_options[@]}\" | grep -q -- '--border'
	"
	[ "$status" -eq 0 ]
}

@test "_aws_fzf_options: preserves quoted --bind value with spaces as single token (FZF_AWS_FLAGS)" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		export FZF_AWS_FLAGS=\"--bind 'alt-I:execute(aws s3 ls {1} | less)'\"
		_aws_fzf_options
		printf '%s\n' \"\${_fzf_options[@]}\" | grep -qx -- 'alt-I:execute(aws s3 ls {1} | less)'
	"
	[ "$status" -eq 0 ]
}

@test "_aws_fzf_options: preserves quoted --bind value with spaces as single token (FZF_AWS_SECRET_OPTS)" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		export FZF_AWS_SECRET_OPTS=\"--bind 'alt-I:execute(aws secretsmanager get-secret-value --secret-id {1} | less)'\"
		_aws_fzf_options SECRET
		printf '%s\n' \"\${_fzf_options[@]}\" | grep -qx -- 'alt-I:execute(aws secretsmanager get-secret-value --secret-id {1} | less)'
	"
	[ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# _copy_to_clipboard
# ---------------------------------------------------------------------------

@test "_copy_to_clipboard: writes the given text to the clipboard" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		_copy_to_clipboard 'hello-clipboard' 'test value'
	"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_CLIPBOARD")" = "hello-clipboard" ]
}

@test "_copy_to_clipboard: fails when no clipboard tool is available" {
	# Remove pbcopy from mock bin and restrict PATH to only MOCK_BIN so the
	# real /usr/bin/pbcopy (macOS) is not found either.
	rm -f "$MOCK_BIN/pbcopy"
	run -127 bash -c "
		export PATH='$MOCK_BIN'
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		_copy_to_clipboard 'some-value' 'test'
	"
	[ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# _open_url
# ---------------------------------------------------------------------------

@test "_open_url: opens the given URL in the browser" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		_open_url 'https://console.aws.amazon.com/test'
	"
	[ "$status" -eq 0 ]
	[ "$(cat "$MOCK_URL_FILE")" = "https://console.aws.amazon.com/test" ]
}

# ---------------------------------------------------------------------------
# _get_aws_context
# ---------------------------------------------------------------------------

@test "_get_aws_context: returns the context as account-region" {
	cat > "$MOCK_BIN/aws" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2 $3" in
  "sts get-caller-identity") echo '{"Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/test"}' ;;
  "configure get region") echo "us-east-1" ;;
  *) echo "{}" ;;
esac
MOCK
	chmod +x "$MOCK_BIN/aws"

	run bash -c "
		export PATH='$MOCK_BIN:\$PATH'
		export AWS_REGION=us-east-1
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		_get_aws_context
	"
	[ "$status" -eq 0 ]
	[[ "$output" =~ -us-east-1$ ]]
}

# ---------------------------------------------------------------------------
# Source guard
# ---------------------------------------------------------------------------

@test "source guard: is a no-op when the script is sourced a second time" {
	run bash -c "
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		# Sourcing again should be a no-op (guard returns 0 early)
		source '$PROJECT_ROOT/scripts/aws_core.sh'
		echo 'double-source-ok'
	"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "double-source-ok" ]]
}
