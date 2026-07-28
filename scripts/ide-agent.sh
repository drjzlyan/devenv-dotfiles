#!/usr/bin/env bash
set -euo pipefail

# In-session agent management for the tmux IDE.
#
# Called by tmux keybindings (prefix + A / N / D) to switch, cycle,
# or reset coding agents without leaving Neovim.
#
# Usage:
#   ide-agent.sh switch   # interactive agent picker (command-prompt)
#   ide-agent.sh next     # cycle to the next agent
#   ide-agent.sh prev     # cycle to the previous agent
#   ide-agent.sh reset    # reset pane layout to default
#   ide-agent.sh status   # show current agent and available agents
#
# State is read from tmux session options set by dev.sh:
#   @ide_agents         space-separated list of available agents
#   @ide_current_agent  currently active agent
#   @ide_agent_pane     pane ID of the agent pane
#   @ide_workdir        working directory

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

KNOWN_AGENTS=("crush" "claude" "codex" "gemini" "aider" "copilot")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

get_session() {
  tmux display-message -p "#{session_name}" 2>/dev/null || echo ""
}

get_opt() {
  local session="$1"
  local name="$2"
  tmux show-option -t "$session" -v "$name" 2>/dev/null || echo ""
}

set_opt() {
  local session="$1"
  local name="$2"
  local value="$3"
  tmux set-option -t "$session" "$name" "$value" 2>/dev/null || true
}

detect_agents() {
  local found=()
  for agent in "${KNOWN_AGENTS[@]}"; do
    command -v "$agent" >/dev/null 2>&1 && found+=("$agent")
  done
  printf '%s\n' "${found[@]}"
}

ensure_agents() {
  local session="$1"
  local agents
  agents=$(get_opt "$session" "@ide_agents")
  if [[ -z "$agents" ]]; then
    detected=()
    while IFS= read -r line; do
      [[ -n "$line" ]] && detected+=("$line")
    done < <(detect_agents)
    agents="${detected[*]}"
    set_opt "$session" "@ide_agents" "$agents"
  fi
  echo "$agents"
}

ensure_current() {
  local session="$1"
  local current
  current=$(get_opt "$session" "@ide_current_agent")
  if [[ -z "$current" ]]; then
    current="none"
    set_opt "$session" "@ide_current_agent" "none"
  fi
  echo "$current"
}

# ---------------------------------------------------------------------------
# Launch an agent in the agent pane
# ---------------------------------------------------------------------------

launch_in_pane() {
  local session="$1"
  local agent="$2"
  local workdir
  workdir=$(get_opt "$session" "@ide_workdir")
  [[ -z "$workdir" ]] && workdir="$HOME"
  local agent_pane
  agent_pane=$(get_opt "$session" "@ide_agent_pane")

  # Check if the agent pane still exists
  local pane_exists=false
  if [[ -n "$agent_pane" ]]; then
    if tmux list-panes -t "$session:dev" -F "#{pane_id}" 2>/dev/null | grep -q "^${agent_pane}$"; then
      pane_exists=true
    fi
  fi

  if [[ "$pane_exists" == false ]]; then
    # Pane is gone — reset the layout first
    reset_layout "$session"
    agent_pane=$(get_opt "$session" "@ide_agent_pane")
  fi

  # Respawn the pane (kills existing process, opens a fresh shell)
  tmux respawn-pane -t "$agent_pane" -k -c "$workdir" 2>/dev/null || true
  sleep 0.3

  # Launch the agent
  if [[ "$agent" != "none" ]] && command -v "$agent" >/dev/null 2>&1; then
    tmux send-keys -t "$agent_pane" "$agent" Enter
  fi

  # Update state
  set_opt "$session" "@ide_current_agent" "$agent"
  tmux select-pane -t "$agent_pane" -T "agent" 2>/dev/null || true
  tmux select-pane -t "$session:dev.1" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Reset layout to default
# ---------------------------------------------------------------------------

reset_layout() {
  local session="$1"
  local workdir
  workdir=$(get_opt "$session" "@ide_workdir")
  [[ -z "$workdir" ]] && workdir="$HOME"

  # Check if the dev window exists
  if ! tmux list-windows -t "$session" -F "#{window_name}" 2>/dev/null | grep -q "^dev$"; then
    tmux display-message "No 'dev' window in session '$session'"
    return 1
  fi

  # Get current pane count
  local pane_count
  pane_count=$(tmux list-panes -t "$session:dev" 2>/dev/null | wc -l | tr -d ' ')

  # Kill all panes except the first (nvim), in reverse order
  if [[ "$pane_count" -gt 1 ]]; then
    local panes
    panes=$(tmux list-panes -t "$session:dev" -F "#{pane_index}" 2>/dev/null | sort -rn)
    for pane in $panes; do
      [[ "$pane" != "1" ]] && tmux kill-pane -t "$session:dev.$pane" 2>/dev/null || true
    done
  fi

  # Recreate the right-side layout
  tmux split-window -h -l 35% -t "$session:dev.1" -c "$workdir"
  tmux split-window -v -l 40% -t "$session:dev.2" -c "$workdir"
  tmux select-pane -t "$session:dev.2" -T "agent"
  tmux select-pane -t "$session:dev.3" -T "build/test"

  # Update stored pane IDs
  local agent_pane
  agent_pane=$(tmux display-message -p -t "$session:dev.2" "#{pane_id}")
  set_opt "$session" "@ide_agent_pane" "$agent_pane"

  # Launch the current agent in the agent pane
  local current
  current=$(ensure_current "$session")
  if [[ "$current" != "none" ]] && command -v "$current" >/dev/null 2>&1; then
    tmux send-keys -t "$session:dev.2" "$current" Enter
  fi

  # Focus nvim
  tmux select-pane -t "$session:dev.1"
  tmux display-message "Layout reset"
}

# ---------------------------------------------------------------------------
# Cycle to next/previous agent
# ---------------------------------------------------------------------------

cycle_agent() {
  local session="$1"
  local direction="$2"  # "next" or "prev"

  local agents
  agents=$(ensure_agents "$session")
  [[ -z "$agents" ]] && { tmux display-message "No agents available"; return 1; }

  local current
  current=$(ensure_current "$session")

  # shellcheck disable=SC2206
  local agent_list=($agents)
  local count=${#agent_list[@]}
  local idx=0
  local found=false

  for i in "${!agent_list[@]}"; do
    if [[ "${agent_list[$i]}" == "$current" ]]; then
      idx=$i
      found=true
      break
    fi
  done

  if [[ "$found" == false ]]; then
    # Current agent not in list — start from the beginning
    idx=-1
  fi

  if [[ "$direction" == "next" ]]; then
    idx=$((idx + 1))
    [[ $idx -ge $count ]] && idx=0
  else
    idx=$((idx - 1))
    [[ $idx -lt 0 ]] && idx=$((count - 1))
  fi

  local next_agent="${agent_list[$idx]}"
  launch_in_pane "$session" "$next_agent"
  tmux display-message "Agent: $next_agent"
}

# ---------------------------------------------------------------------------
# Interactive switch (tmux command-prompt)
# ---------------------------------------------------------------------------

switch_interactive() {
  local session="$1"

  local agents
  agents=$(ensure_agents "$session")
  local current
  current=$(ensure_current "$session")

  if [[ -z "$agents" ]]; then
    tmux display-message "No agents detected"
    return 1
  fi

  local prompt="Switch agent [$agents] (current: $current, or 'none'):"
  tmux command-prompt -p "$prompt" "run-shell '$SCRIPT_PATH switch_to %%'"
}

# Switch to a specific agent (called from command-prompt)
switch_to() {
  local session="$1"
  local agent="$2"

  # Validate
  if [[ "$agent" != "none" ]] && ! command -v "$agent" >/dev/null 2>&1; then
    tmux display-message "Agent '$agent' not found"
    return 1
  fi

  launch_in_pane "$session" "$agent"
  tmux display-message "Agent: $agent"
}

# ---------------------------------------------------------------------------
# Status display
# ---------------------------------------------------------------------------

show_status() {
  local session
  session=$(get_session)
  if [[ -z "$session" ]]; then
    echo "Not in a tmux session"
    exit 1
  fi

  local agents
  agents=$(ensure_agents "$session")
  local current
  current=$(ensure_current "$session")

  echo "Session: $session"
  echo "Current agent: $current"
  echo "Available agents: ${agents:-none detected}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  local cmd="${1:-status}"
  shift || true

  local session
  session=$(get_session)
  if [[ -z "$session" ]]; then
    echo "Not in a tmux session"
    exit 1
  fi

  case "$cmd" in
    switch)
      switch_interactive "$session"
      ;;
    switch_to)
      switch_to "$session" "${1:-none}"
      ;;
    next)
      cycle_agent "$session" "next"
      ;;
    prev)
      cycle_agent "$session" "prev"
      ;;
    reset)
      reset_layout "$session"
      ;;
    status)
      show_status
      ;;
    *)
      echo "Usage: ide-agent.sh [switch|switch_to <name>|next|prev|reset|status]"
      exit 1
      ;;
  esac
}

main "$@"
