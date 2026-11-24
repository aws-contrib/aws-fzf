#!/usr/bin/env bash
set -euo pipefail

# Called from an fzf execute-silent binding. Never wait for the floating pane.
case "${1:-}" in
available)
	[[ -n "${TMUX:-}" ]] && command -v tmux-view &>/dev/null || exit 1
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
	border_status=$(tmux show-options -wqv pane-border-status 2>/dev/null || true)
	if [[ -z "$border_status" || "$border_status" == off ]]; then
		tmux set-option -w pane-border-status top-floating
	fi
	command=(aws logs tail "$group" --follow --format detailed --no-cli-pager)
	if [[ $# -ge 2 ]]; then
		command+=(--log-stream-names "$2")
	fi
	tmux new-pane -x '80%' -y '70%' -X '10%' -Y '15%' -c "$PWD" \
		-T " CloudWatch $title " -- tmux-view -- "${command[@]}"
	;;
*) exit 1 ;;
esac
