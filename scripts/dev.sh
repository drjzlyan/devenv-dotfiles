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
# Git workflow:
#   Window 2 (git) → lazygit opens automatically on session start
#   From any pane → Ctrl-a g switches to the git window (or creates one)
#
# Usage:
#   dev                     # session named after current dir
#   dev myproject           # session named "myproject"
#   dev myproject ~/code    # session + path
#   dev -a claude           # use a specific agent
#   dev -a none             # skip agent, open a shell instead
#   dev -k                  # kill existing session if present
#   dev -q                  # quit (kill) the session cleanly
#
# Agent preference persistence:
#   The chosen agent is saved per-project in
#   ~/.local/share/nvim/ide-preferences.local so the next `dev` in the
#   same directory uses the same agent without prompting.  Use
#   `dev -a <agent>` to override (which also updates the preference).
#
# In-session agent management (tmux keybindings):
#   Prefix + A    Switch agent (interactive prompt)
#   Prefix + N    Next agent (cycle forward)
#   Prefix + D    Reset layout to default

# Known coding agents, in preference order.
KNOWN_AGENTS=("crush" "claude" "codex" "gemini" "aider" "copilot")

PREFS_FILE="${PREFS_FILE:-$HOME/.local/share/nvim/ide-preferences.local}"

AGENT=""
SESSION_NAME=""
WORKDIR=""
KILL_EXISTING=0
QUIT=0

while getopts "a:kq" opt; do
  case "$opt" in
    a) AGENT="$OPTARG" ;;
    k) KILL_EXISTING=1 ;;
    q) QUIT=1 ;;
    *) ;;
  esac
done
shift $((OPTIND - 1))

SESSION_NAME="${1:-$(basename "$(pwd)")}"
WORKDIR="${2:-$(pwd)}"

WORKDIR="${WORKDIR/#\~/$HOME}"

# ---------------------------------------------------------------------------
# Preferences: per-project agent preference
# ---------------------------------------------------------------------------

load_pref() {
  local key="$1"
  [[ -f "$PREFS_FILE" ]] || return 0
  grep -E "^${key}=" "$PREFS_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true
}

save_pref() {
  local key="$1"
  local value="$2"
  mkdir -p "$(dirname "$PREFS_FILE")"
  touch "$PREFS_FILE"
  # Remove existing entry for this key, then append
  local tmp
  tmp=$(grep -vE "^${key}=" "$PREFS_FILE" 2>/dev/null || true)
  {
    echo "$tmp"
    echo "${key}=${value}"
  } > "$PREFS_FILE"
}

# ---------------------------------------------------------------------------
# Quit: kill the session cleanly
# ---------------------------------------------------------------------------

if [[ "$QUIT" == 1 ]]; then
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    # Save nvim sessions if auto-session is configured
    tmux send-keys -t "$SESSION_NAME:dev.1" ":qa!" Enter 2>/dev/null || true
    sleep 1
    tmux kill-session -t "$SESSION_NAME"
    echo "Session '$SESSION_NAME' terminated."
  else
    echo "Session '$SESSION_NAME' does not exist."
  fi
  exit 0
fi

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

  echo "" >&2
  echo "  Multiple coding agents detected:" >&2
  echo "" >&2
  local i=1
  for agent in "${agents[@]}"; do
    printf "  %d. %s\n" "$i" "$agent" >&2
    i=$((i + 1))
  done
  echo "  0. none (just a shell)" >&2
  echo "" >&2
  echo "  Enter a number, type a command name, or Enter for #1." >&2
  echo "  Ctrl-C cancels (opens a shell)." >&2
  echo "" >&2

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

# Resolve agent: -a flag > saved preference > auto-detect > interactive menu
detected=()
if [[ -z "$AGENT" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && detected+=("$line")
  done < <(detect_agents)

  # Check saved preference for this project
  saved_agent=$(load_pref "agent.${WORKDIR}")
  if [[ -n "$saved_agent" ]]; then
    if [[ "$saved_agent" == "none" ]] || command -v "$saved_agent" >/dev/null 2>&1; then
      AGENT="$saved_agent"
    fi
  fi
fi

if [[ -z "$AGENT" ]]; then
  if [[ ${#detected[@]} -eq 0 ]]; then
    AGENT="none"
  elif [[ ${#detected[@]} -eq 1 ]]; then
    AGENT="${detected[0]}"
  else
    AGENT=$(select_agent_interactive "${detected[@]}")
  fi
fi

# Save the agent preference for this project
save_pref "agent.${WORKDIR}" "$AGENT"

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
    sleep 1
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

# ── Window 2: git ──────────────────────────────────────────────
tmux new-window -t "$SESSION_NAME" -n git -c "$WORKDIR" "lazygit"

# ── Attach ─────────────────────────────────────────────────────
exec tmux attach -t "$SESSION_NAME:dev"
