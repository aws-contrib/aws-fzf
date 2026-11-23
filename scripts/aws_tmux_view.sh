#!/usr/bin/env bash
set -euo pipefail

# Open a non-modal tmux 3.8 floating pane for a live CloudWatch tail.
# Called by an fzf execute-silent binding; never wait for the pane here.
case "${1:-}" in
available)
	[[ -n "${TMUX:-}" ]] || exit 1
	version=$(tmux display-message -p '#{version}' 2>/dev/null) || exit 1
	[[ $version =~ ^([0-9]+)\.([0-9]+) ]] || exit 1
	(( 10#${BASH_REMATCH[1]} > 3 || (10#${BASH_REMATCH[1]} == 3 && 10#${BASH_REMATCH[2]} >= 8) ))
	;;
open)
	shift
	[[ $# -ge 1 ]] || exit 1
	"$0" available || exit 1
	group=$1
	# Keep names out of tmux formats (notably #) and bound title length.
	title=${group//\#/}
	title=${title:0:60}
	tmux new-pane -x '80%' -y '70%' -X '10%' -Y '15%' \
		-T " CloudWatch $title " "$0" watch "$@"
	;;
watch)
	shift
	[[ $# -ge 1 ]] || exit 1
	# The reader owns the tty; the AWS CLI must not consume its input.
	"$(dirname -- "$0")/aws_log_cmd.sh" tail-log "$@" </dev/null &
	pid=$!
	trap 'kill "$pid" 2>/dev/null || true' EXIT
	printf 'Press q to stop tailing.\n'
	while kill -0 "$pid" 2>/dev/null; do
		key=''
		if IFS= read -rsn1 -t 0.2 key </dev/tty && [[ $key == q ]]; then
			kill "$pid" 2>/dev/null || true
			wait "$pid" 2>/dev/null || true
			exit 0
		fi
	done
	wait "$pid" || true
	printf '\nTail finished. Press q to close.\n'
	while IFS= read -rsn1 key </dev/tty; do
		[[ $key == q ]] && break
	done
	;;
*) exit 1 ;;
esac
