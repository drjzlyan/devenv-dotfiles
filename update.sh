#!/usr/bin/env bash
# Update all installed tooling. Idempotent and safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source_brew_env() {
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

log() {
  printf '[dotfiles] %s\n' "$*"
}

source_brew_env

log "Updating Homebrew..."
brew update

log "Reconciling Brewfile..."
brew bundle --file="$REPO_ROOT/Brewfile"

log "Upgrading packages..."
brew upgrade || true

log "Cleaning up..."
brew cleanup || true

log "Updating uv..."
uv self update 2>/dev/null || true

log "Updating mise runtimes..."
mise install 2>/dev/null || true

log "Updating external tools (for selected languages)..."
local tool_script="$REPO_ROOT/../nvim-config/scripts/update-tools.sh"
if [[ -x "$tool_script" ]]; then
  "$tool_script" 2>/dev/null || true
fi

log "Updating editor plugins..."
if command -v nvim >/dev/null 2>&1; then
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi

log "Running health check..."
"$REPO_ROOT/doctor.sh" || true

log "Update complete."
log "  To add or remove languages: ~/Development/dotfiles/scripts/languages.sh"
