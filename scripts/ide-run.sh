#!/usr/bin/env bash
set -euo pipefail

# Send a shell command to the "build/test" pane of the current tmux session.
# The pane is reused whenever it exists and created on demand when it does
# not, so build/test/any shell output stays in tmux instead of a separate
# editor terminal.
#
# Usage:
#   ide-run [options] <command>
#   ide-run --focus                     focus the build/test pane (no command)
#
# Options:
#   -d DIR    run the command in DIR (cd first)
#   -s NAME   tmux session (default: derived from TMUX_PANE or client)
#   -h        show this help
#
# Pane resolution order:
#   1. any live pane in the session titled "build/test"
#   2. pane 3 of the "dev" window (IDE layout)
#   3. a new split from the editor pane (dev.1) or the active pane

DIR=""
SESSION=""
FOCUS=0

args=()
for arg in "$@"; do
  if [[ "$arg" == "--focus" ]]; then
    FOCUS=1
  else
    args+=("$arg")
  fi
done
if [[ ${#args[@]} -gt 0 ]]; then
  set -- "${args[@]}"
else
  set --
fi

while getopts "d:s:h" opt; do
  case "$opt" in
    d) DIR="$OPTARG" ;;
    s) SESSION="$OPTARG" ;;
    h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) exit 1 ;;
  esac
done
shift $((OPTIND - 1))

CMD="${*:-}"

if [[ "$FOCUS" == 0 && -z "$CMD" ]]; then
  echo "Usage: ide-run [-d dir] [-s session] <command> | ide-run --focus" >&2
  exit 1
fi

if [[ -z "${TMUX:-}" && -z "${TMUX_PANE:-}" && -z "$SESSION" ]]; then
  # Not inside tmux: run the command directly.
  if [[ -n "$DIR" ]]; then
    cd "$DIR"
  fi
  exec bash -c "$CMD"
fi

resolve_session() {
  if [[ -n "$SESSION" ]]; then
    echo "$SESSION"
    return 0
  fi
  if [[ -n "${TMUX_PANE:-}" ]]; then
    tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null && return 0
  fi
  tmux display-message -p '#{session_name}' 2>/dev/null
}

SESSION=$(resolve_session || true)
if [[ -z "$SESSION" ]]; then
  echo "ide-run: could not determine tmux session" >&2
  exit 1
fi

set_opt() {
  tmux set-option -t "$SESSION" "$1" "$2" 2>/dev/null || true
}

find_pane() {
  tmux list-panes -s -t "$SESSION" -F '#{pane_id} #{pane_title}' 2>/dev/null \
    | awk '$2=="build/test"{print $1; exit}'
}

create_pane() {
  local target new_pane
  # Prefer splitting below the agent pane in the dev window (IDE layout).
  if tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -q '^dev$'; then
    if tmux list-panes -t "$SESSION:dev" -F '#{pane_index}' 2>/dev/null | grep -q '^2$'; then
      target="$SESSION:dev.2"
    else
      target="$SESSION:dev.1"
    fi
  else
    target="$SESSION"
  fi
  new_pane=$(tmux split-window -v -l 40% -t "$target" -P -F '#{pane_id}' 2>/dev/null) || return 1
  tmux select-pane -t "$new_pane" -T "build/test" 2>/dev/null || true
  echo "$new_pane"
}

PANE=$(find_pane || true)

if [[ -z "$PANE" ]] && tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -q '^dev$'; then
  if tmux list-panes -t "$SESSION:dev" -F '#{pane_index}' 2>/dev/null | grep -q '^3$'; then
    PANE=$(tmux display-message -p -t "$SESSION:dev.3" '#{pane_id}' 2>/dev/null || true)
    [[ -n "$PANE" ]] && tmux select-pane -t "$PANE" -T "build/test" 2>/dev/null || true
  fi
fi

if [[ -z "$PANE" ]]; then
  PANE=$(create_pane || true)
fi

if [[ -z "$PANE" ]]; then
  echo "ide-run: could not find or create a build/test pane" >&2
  exit 1
fi

set_opt "@ide_shell_pane" "$PANE"

if [[ "$FOCUS" == 1 ]]; then
  tmux select-window -t "$PANE" 2>/dev/null || true
  tmux select-pane -t "$PANE" 2>/dev/null || true
  exit 0
fi

if [[ -n "$DIR" ]]; then
  tmux send-keys -t "$PANE" "cd -- $(printf '%q' "$DIR") && $CMD" Enter
else
  tmux send-keys -t "$PANE" "$CMD" Enter
fi
