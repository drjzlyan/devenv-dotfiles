#!/usr/bin/env bash
set -euo pipefail

# Start an automated dev session in tmux.
#
# Layout:
#   ┌──────────────────────┬──────────────────┐
#   │                      │                  │
#   │                      │  agent           │
#   │                      │  (crush/claude)  │
#   │      nvim            │                  │
#   │                      ├──────────────────┤
#   │                      │                  │
#   │                      │  build / test    │
#   │                      │  shell           │
#   └──────────────────────┴──────────────────┘
#
#   Window 2 "git":  lazygit (fullscreen)
#
# Usage:
#   dev                     # session named after current dir
#   dev myproject           # session named "myproject"
#   dev myproject ~/code    # session + path
#   dev -a claude           # use claude-code instead of crush
#   dev -a gemini            # use gemini-cli
#   dev -a none             # skip agent, open a shell instead
#   dev -k                  # kill existing session if present

AGENT="${AGENT:-crush}"
SESSION_NAME=""
WORKDIR=""
KILL_EXISTING=0

while getopts "a:k" opt; do
  case "$opt" in
    a) AGENT="$OPTARG" ;;
    k) KILL_EXISTING=1 ;;
    *) ;;
  esac
done
shift $((OPTIND - 1))

SESSION_NAME="${1:-$(basename "$(pwd)")}"
WORKDIR="${2:-$(pwd)}"

WORKDIR="${WORKDIR/#\~/$HOME}"

if [[ ! -d "$WORKDIR" ]]; then
  echo "Error: directory '$WORKDIR' does not exist."
  exit 1
fi

tmux has-session -t "$SESSION_NAME" 2>/dev/null && {
  if [[ "$KILL_EXISTING" == "1" ]]; then
    tmux kill-session -t "$SESSION_NAME"
  else
    echo "Session '$SESSION_NAME' already exists. Attaching."
    exec tmux attach -t "$SESSION_NAME"
  fi
}

# ── Window 1: dev ──────────────────────────────────────────────
tmux new-session -d -s "$SESSION_NAME" -n dev -c "$WORKDIR"

# Left pane: nvim (65% width)
tmux send-keys -t "$SESSION_NAME:dev.1" "nvim" Enter

# Split right pane (35% width)
tmux split-window -h -l 35% -t "$SESSION_NAME:dev.1" -c "$WORKDIR"

# Split right pane vertically: agent (60%) on top, shell (40%) on bottom
tmux split-window -v -l 40% -t "$SESSION_NAME:dev.2" -c "$WORKDIR"

# Right-top pane: agent
case "$AGENT" in
  none) ;;
  crush)     tmux send-keys -t "$SESSION_NAME:dev.2" "crush" Enter ;;
  claude)   tmux send-keys -t "$SESSION_NAME:dev.2" "claude" Enter ;;
  codex)    tmux send-keys -t "$SESSION_NAME:dev.2" "codex" Enter ;;
  gemini)   tmux send-keys -t "$SESSION_NAME:dev.2" "gemini" Enter ;;
  *)
    if command -v "$AGENT" >/dev/null 2>&1; then
      tmux send-keys -t "$SESSION_NAME:dev.2" "$AGENT" Enter
    fi
    ;;
esac

# Right-bottom pane: build/test shell (stays at prompt)
tmux select-pane -t "$SESSION_NAME:dev.3" -T "build/test"

# Focus nvim
tmux select-pane -t "$SESSION_NAME:dev.1"

# ── Window 2: git ───────────────────────────────────────────────
if command -v lazygit >/dev/null 2>&1; then
  tmux new-window -t "$SESSION_NAME" -n git -c "$WORKDIR"
  tmux send-keys -t "$SESSION_NAME:git.1" "lazygit" Enter
fi

# ── Attach ─────────────────────────────────────────────────────
exec tmux attach -t "$SESSION_NAME:dev"
