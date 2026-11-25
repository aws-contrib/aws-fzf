#!/usr/bin/env bats

setup() {
  VIEW="$BATS_TEST_DIRNAME/../scripts/aws_tmux_view.sh"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == display-message ]]; then
  printf '%s\n' "$MOCK_TMUX_VERSION"
else
  printf '%s\n' "$@" >> "$TMUX_ARGS"
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/bin/tmux"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  export TMUX=/tmp/test-socket
  export TMUX_ARGS="$BATS_TEST_TMPDIR/tmux.args"
}

@test 'floating tail requires a tmux server of at least 3.8' {
  export MOCK_TMUX_VERSION=3.7
  run "$VIEW" available
  [ "$status" -ne 0 ]
  export MOCK_TMUX_VERSION=3.8
  run "$VIEW" available
  [ "$status" -eq 0 ]
  export MOCK_TMUX_VERSION=4.0
  run "$VIEW" available
  [ "$status" -eq 0 ]
  unset TMUX
  run "$VIEW" available
  [ "$status" -ne 0 ]
}

@test 'open creates a centered modal pane with preserved arguments' {
  export MOCK_TMUX_VERSION=3.8
  run "$VIEW" open '/aws/lambda/hello world' 'stream name'
  [ "$status" -eq 0 ]
  grep -qx -- 'new-pane' "$TMUX_ARGS"
  grep -qx -- '80%' "$TMUX_ARGS"
  grep -qx -- '-O' "$TMUX_ARGS"
  grep -qx -- '-D' "$TMUX_ARGS"
  grep -qx -- 'bash' "$TMUX_ARGS"
  grep -qx -- '"$@"; read -rsn1' "$TMUX_ARGS"
  grep -qx -- 'aws' "$TMUX_ARGS"
  grep -qx -- 'tail' "$TMUX_ARGS"
  grep -qx -- '/aws/lambda/hello world' "$TMUX_ARGS"
  grep -qx -- '--log-stream-names' "$TMUX_ARGS"
  grep -qx -- 'stream name' "$TMUX_ARGS"
  ! grep -qx -- '-W' "$TMUX_ARGS"
}

@test 'open enables floating border titles without changing user border formats' {
  export MOCK_TMUX_VERSION=3.8
  run "$VIEW" open 'group#name'
  [ "$status" -eq 0 ]
  grep -qx -- 'top-floating' "$TMUX_ARGS"
  grep -qx -- ' CloudWatch groupname ' "$TMUX_ARGS"
  ! grep -qx -- '--log-stream-names' "$TMUX_ARGS"
}

@test 'available without tmux-view' {
  export MOCK_TMUX_VERSION=3.8
  ln -s "$(command -v bash)" "$BATS_TEST_TMPDIR/bin/bash"
  export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin"
  run "$VIEW" available
  [ "$status" -eq 0 ]
  run "$VIEW" open group
  [ "$status" -eq 0 ]
}
