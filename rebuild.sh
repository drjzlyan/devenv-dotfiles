#!/usr/bin/env bash
# Rebuild the development environment after pulling updates.
#
# Pulls the latest changes for dotfiles and nvim-config, re-links
# config files, regenerates mise.toml from the existing language
# selection (if any), reinstalls tools, syncs nvim plugins, and
# runs a health check.
#
# Safe to run repeatedly. Preserves:
#   - ~/.local/share/nvim/languages.local (language + version selection)
#   - ~/.gitconfig.local (Git identity)
#   - nvim sessions, swap, and plugin state
#   - mise-installed runtimes
#   - tmux sessions
#
# Usage:
#   rebuild.sh           # pull, relink, regenerate, reinstall, verify
#   rebuild.sh --no-pull  # skip git pull (use local changes as-is)
#   rebuild.sh --dry-run  # show what would happen without making changes

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_PATH="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}"
LANGUAGES_FILE="$HOME/.local/share/nvim/languages.local"

PULL=1
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --no-pull) PULL=0 ;;
    --dry-run) DRY_RUN=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

log() {
  printf '[rebuild] %s\n' "$*"
}

run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '[rebuild] (dry-run) %s\n' "$*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# Step 1: Pull latest changes
# ---------------------------------------------------------------------------

step_pull() {
  if [[ "$PULL" == 0 ]]; then
    log "Skipping git pull (--no-pull)"
    return
  fi

  log "Step 1/7: Pulling latest changes..."

  if [[ -d "$REPO_ROOT/.git" ]]; then
    local before_dot after_dot
    before_dot=$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "?")
    run git -C "$REPO_ROOT" pull --ff-only 2>/dev/null || log "  dotfiles: pull failed (continuing with local state)"
    after_dot=$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "?")
    if [[ "$before_dot" != "$after_dot" ]]; then
      log "  dotfiles: $before_dot -> $after_dot"
    else
      log "  dotfiles: already up to date ($after_dot)"
    fi
  fi

  if [[ -d "$NVIM_CONFIG_PATH/.git" ]]; then
    local before_nvim after_nvim
    before_nvim=$(cd "$NVIM_CONFIG_PATH" && git rev-parse --short HEAD 2>/dev/null || echo "?")
    run git -C "$NVIM_CONFIG_PATH" pull --ff-only 2>/dev/null || log "  nvim-config: pull failed (continuing with local state)"
    after_nvim=$(cd "$NVIM_CONFIG_PATH" && git rev-parse --short HEAD 2>/dev/null || echo "?")
    if [[ "$before_nvim" != "$after_nvim" ]]; then
      log "  nvim-config: $before_nvim -> $after_nvim"
    else
      log "  nvim-config: already up to date ($after_nvim)"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Step 2: Backup non-symlinked config files
# ---------------------------------------------------------------------------

step_backup() {
  log "Step 2/7: Backing up non-symlinked config files..."

  if [[ "$DRY_RUN" == 1 ]]; then
    log "  (dry-run — skipping backup)"
    return
  fi

  if [[ -x "$REPO_ROOT/scripts/backup.sh" ]]; then
    "$REPO_ROOT/scripts/backup.sh" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Step 3: Re-link dotfiles
# ---------------------------------------------------------------------------

step_link() {
  log "Step 3/7: Re-linking dotfiles..."
  run "$REPO_ROOT/link.sh"
}

# ---------------------------------------------------------------------------
# Step 4: Regenerate mise.toml from existing language selection
# ---------------------------------------------------------------------------

step_mise() {
  log "Step 4/7: Regenerating mise.toml from language selection..."

  if [[ ! -f "$LANGUAGES_FILE" ]]; then
    log "  No languages.local found — skipping mise.toml generation"
    log "  Run: ~/Development/dotfiles/scripts/languages.sh"
    return
  fi

  if [[ "$DRY_RUN" == 1 ]]; then
    log "  (dry-run — would regenerate mise.toml from:)"
    cat "$LANGUAGES_FILE" | sed 's/^/    /'
    return
  fi

  if [[ -x "$REPO_ROOT/scripts/languages.sh" ]]; then
    "$REPO_ROOT/scripts/languages.sh" --list 2>/dev/null || true
    "$REPO_ROOT/scripts/languages.sh" --regenerate 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Step 5: Reinstall language tools
# ---------------------------------------------------------------------------

step_tools() {
  log "Step 5/7: Reinstalling language tools..."

  if [[ ! -f "$LANGUAGES_FILE" ]]; then
    log "  No languages selected — skipping tool installation"
    return
  fi

  local tool_script="$NVIM_CONFIG_PATH/scripts/install-tools.sh"
  if [[ -x "$tool_script" ]]; then
    run "$tool_script"
  else
    log "  install-tools.sh not found at $tool_script"
  fi
}

# ---------------------------------------------------------------------------
# Step 6: Sync nvim plugins
# ---------------------------------------------------------------------------

step_plugins() {
  log "Step 6/7: Syncing nvim plugins..."

  if [[ "$DRY_RUN" == 1 ]]; then
    log "  (dry-run — would run :Lazy! sync)"
    return
  fi

  if command -v nvim >/dev/null 2>&1; then
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    log "  Plugin sync complete"
  else
    log "  nvim not found — skipping plugin sync"
  fi
}

# ---------------------------------------------------------------------------
# Step 7: Health check
# ---------------------------------------------------------------------------

step_health() {
  log "Step 7/7: Running health check..."
  run "$REPO_ROOT/doctor.sh" || true
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

summary() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Rebuild complete"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Show what was preserved
  echo "  Preserved:"
  if [[ -f "$LANGUAGES_FILE" ]]; then
    echo "    ✓ Language selection: $(grep -cE '^[a-z]+=' "$LANGUAGES_FILE" 2>/dev/null || echo 0) languages"
  else
    echo "    — No language selection (run: scripts/languages.sh)"
  fi

  if [[ -f "$HOME/.gitconfig.local" ]]; then
    echo "    ✓ Git identity: $(grep -A1 '\[user\]' "$HOME/.gitconfig.local" | grep email | sed 's/.*= //')"
  else
    echo "    — No gitconfig.local (create with your name/email)"
  fi

  echo "    ✓ nvim sessions and plugin state"
  echo "    ✓ mise-installed runtimes"
  echo ""

  # Show current state
  if [[ -f "$LANGUAGES_FILE" ]] && grep -qE '^[a-z]+=' "$LANGUAGES_FILE" 2>/dev/null; then
    echo "  Current languages:"
    grep -E '^[a-z]+=' "$LANGUAGES_FILE" | sed 's/^/    /'
    echo ""
  fi

  echo "  Next steps:"
  echo "    dev                    # start a tmux dev session"
  echo "    scripts/languages.sh   # add/remove languages or change versions"
  echo "    update.sh              # routine maintenance (brew, mise, plugins)"
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo "  Rebuilding development environment"
  echo "═══════════════════════════════════════════════════════════"
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "  (DRY RUN — no changes will be made)"
  fi
  echo ""

  step_pull
  step_backup
  step_link
  step_mise
  step_tools
  step_plugins
  step_health

  summary
}

main "$@"
