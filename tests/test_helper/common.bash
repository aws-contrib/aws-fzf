#!/usr/bin/env bash
#
# Common test helpers for aws-fzf bats tests
#

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT
FIXTURES="$PROJECT_ROOT/tests/fixtures"
export FIXTURES

# setup_mock_bin()
#
# Creates a temporary directory of mock binaries and prepends it to PATH.
# Sets MOCK_BIN, MOCK_CLIPBOARD, MOCK_URL_FILE exports.
#
setup_mock_bin() {
	MOCK_BIN="$(mktemp -d)"
	MOCK_CLIPBOARD="$MOCK_BIN/clipboard.txt"
	MOCK_URL_FILE="$MOCK_BIN/opened_url.txt"
	export MOCK_BIN MOCK_CLIPBOARD MOCK_URL_FILE

	# Locate real jq BEFORE prepending MOCK_BIN to PATH
	local _real_jq
	_real_jq="$(command -v jq)"
	export PATH="$MOCK_BIN:$PATH"

	# gum: suppress log output, pass spin commands through, cat format
	cat > "$MOCK_BIN/gum" << 'GUMMOCK'
#!/usr/bin/env bash
case "$1" in
  log) ;;
  spin)
    shift
    while [[ $# -gt 0 && "$1" != "--" ]]; do shift; done
    [[ $# -gt 0 ]] && shift
    "$@"
    ;;
  format) cat ;;
  pager) cat ;;
  *) ;;
esac
GUMMOCK
	chmod +x "$MOCK_BIN/gum"

	# pbcopy: write stdin to file for inspection
	cat > "$MOCK_BIN/pbcopy" << PBMOCK
#!/usr/bin/env bash
cat > "$MOCK_CLIPBOARD"
PBMOCK
	chmod +x "$MOCK_BIN/pbcopy"

	# open: record URL for inspection
	cat > "$MOCK_BIN/open" << OPENMOCK
#!/usr/bin/env bash
printf '%s' "\$1" > "$MOCK_URL_FILE"
OPENMOCK
	chmod +x "$MOCK_BIN/open"

	# fzf: report version >= 0.58.0, pass stdin through otherwise
	cat > "$MOCK_BIN/fzf" << 'FZFMOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "0.58.0 (mock)"
  exit 0
fi
cat
FZFMOCK
	chmod +x "$MOCK_BIN/fzf"

	# aws: default returns empty JSON; override per-test as needed
	cat > "$MOCK_BIN/aws" << 'AWSMOCK'
#!/usr/bin/env bash
echo "{}"
AWSMOCK
	chmod +x "$MOCK_BIN/aws"

	# jq: wrapper that injects a _nwise definition so scripts using
	# jq's internal _nwise(n) (removed in jq 1.6+) still work.
	# Prepends "def _nwise(n): ...; " before any bare filter argument.
	cat > "$MOCK_BIN/jq" << JQMOCK
#!/usr/bin/env bash
NWISE='def _nwise(n): if length <= n then . else .[0:n], (.[n:] | _nwise(n)) end; '
ARGS=()
NEXT_IS_FILE_ARG=false
for arg in "\$@"; do
  if [[ "\$NEXT_IS_FILE_ARG" == "true" ]]; then
    ARGS+=("\$arg")
    NEXT_IS_FILE_ARG=false
  elif [[ "\$arg" == "-f" || "\$arg" == "--rawfile" || "\$arg" == "--argjson" || "\$arg" == "--arg" || "\$arg" == "--args" || "\$arg" == "--jsonargs" || "\$arg" == "--slurpfile" ]]; then
    ARGS+=("\$arg")
    NEXT_IS_FILE_ARG=true
  elif [[ "\$arg" == -* ]]; then
    ARGS+=("\$arg")
  else
    ARGS+=("\${NWISE}\$arg")
  fi
done
exec "$_real_jq" "\${ARGS[@]}"
JQMOCK
	chmod +x "$MOCK_BIN/jq"
}

# teardown_mock_bin()
#
# Removes the temporary mock directory created by setup_mock_bin.
#
teardown_mock_bin() {
	rm -rf "$MOCK_BIN"
}

# make_aws_mock_fixture()
#
# Replaces the aws mock to cat a fixture file.
#
# Parameters:
#   $1 - fixture filename (relative to tests/fixtures/)
#
make_aws_mock_fixture() {
	local fixture="$FIXTURES/$1"
	cat > "$MOCK_BIN/aws" << AWSMOCK
#!/usr/bin/env bash
cat "$fixture"
AWSMOCK
	chmod +x "$MOCK_BIN/aws"
}
