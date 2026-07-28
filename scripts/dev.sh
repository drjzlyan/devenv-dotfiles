#!/usr/bin/env bash
set -euo pipefail

# Start an automated dev session in tmux with auto-detected coding agents.
#
# Layout:
#   ┌──────────────────────┬──────────────────┐
#   │                      │                  │
#   │                      │  agent           │
#   │                      │  (auto-detected) │
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
#   dev -a claude           # use a specific agent
#   dev -a none             # skip agent, open a shell instead
#   dev -k                  # kill existing session if present
#
# Agent auto-detection:
#   If -a is not specified, dev scans PATH for known coding agents
#   (crush, claude, codex, gemini, aider, copilot). If multiple are
#   found, an interactive menu is shown. If one is found, it is used
#   automatically. If none are found, a shell opens in the agent pane.
#   If the user cancels the menu, a shell opens (no agent).
#
# In-session agent management (tmux keybindings):
#   Prefix + A    Switch agent (interactive prompt)
#   Prefix + N    Next agent (cycle forward)
#   Prefix + D    Reset layout to default
#
# State is stored in tmux session options:
#   @ide_agents         space-separated list of detected agents
#   @ide_current_agent  currently active agent
#   @ide_agent_pane     pane ID of the agent pane
#   @ide_workdir        working directory for pane creation

# Known coding agents, in preference order.
KNOWN_AGENTS=("crush" "claude" "codex" "gemini" "aider" "copilot")

AGENT=""
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

# ---------------------------------------------------------------------------
# Agent auto-detection
# ---------------------------------------------------------------------------

detect_agents() {
  local found=()
  for agent in "${KNOWN_AGENTS[@]}"; do
    if command -v "$agent" >/dev/null 2>&1; then
      found+=("$agent")
    fi
  done
  printf '%s\n' "${found[@]}"
}

select_agent_interactive() {
  local agents=("$@")
  local count=${#agents[@]}

  if [[ $count -eq 0 ]]; then
    echo "none"
    return
  fi

  if [[ $count -eq 1 ]]; then
    echo "${agents[0]}"
    return
  fi

  echo ""
  echo "  Multiple coding agents detected:"
  echo ""
  local i=1
  for agent in "${agents[@]}"; do
    printf "  %d. %s\n" "$i" "$agent"
    i=$((i + 1))
  done
  echo "  0. none (just a shell)"
  echo ""
  echo "  Enter a number, type a command name, or Enter for #1."
  echo "  Ctrl-C cancels (opens a shell)."
  echo ""

  local choice
  if ! read -rp " > " choice 2>/dev/null; then
    echo "none"
    return
  fi

  if [[ -z "$choice" ]]; then
    echo "${agents[0]}"
  elif [[ "$choice" == "0" ]]; then
    echo "none"
  elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $count ]]; then
    echo "${agents[$((choice - 1))]}"
  elif command -v "$choice" >/dev/null 2>&1; then
    echo "$choice"
  else
    echo "none"
  fi
}

# Resolve agent: -a flag > auto-detect > interactive menu
detected=()
if [[ -z "$AGENT" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && detected+=("$line")
  done < <(detect_agents)

  if [[ ${#detected[@]} -eq 0 ]]; then
    AGENT="none"
  elif [[ ${#detected[@]} -eq 1 ]]; then
    AGENT="${detected[0]}"
  else
    AGENT=$(select_agent_interactive "${detected[@]}")
  fi
fi

# ---------------------------------------------------------------------------
# Session creation
# ---------------------------------------------------------------------------

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
tmux select-pane -t "$SESSION_NAME:dev.2" -T "agent"
if [[ "$AGENT" != "none" ]]; then
  if command -v "$AGENT" >/dev/null 2>&1; then
    tmux send-keys -t "$SESSION_NAME:dev.2" "$AGENT" Enter
  else
    echo "Warning: agent '$AGENT' not found on PATH; opening a shell instead."
  fi
fi

# Right-bottom pane: build/test shell (stays at prompt)
tmux select-pane -t "$SESSION_NAME:dev.3" -T "build/test"

# Focus nvim
tmux select-pane -t "$SESSION_NAME:dev.1"

# Store state in tmux session options for in-session agent management
tmux set-option -t "$SESSION_NAME" @ide_agents "${detected[*]:-${AGENT}}"
tmux set-option -t "$SESSION_NAME" @ide_current_agent "$AGENT"
tmux set-option -t "$SESSION_NAME" @ide_workdir "$WORKDIR"
AGENT_PANE=$(tmux display-message -p -t "$SESSION_NAME:dev.2" "#{pane_id}")
tmux set-option -t "$SESSION_NAME" @ide_agent_pane "$AGENT_PANE"

# ── Window 2: git ───────────────────────────────────────────────
if command -v lazygit >/dev/null 2>&1; then
  tmux new-window -t "$SESSION_NAME" -n git -c "$WORKDIR"
  tmux send-keys -t "$SESSION_NAME:git.1" "lazygit" Enter
fi

# ── Attach ─────────────────────────────────────────────────────
exec tmux attach -t "$SESSION_NAME:dev"
