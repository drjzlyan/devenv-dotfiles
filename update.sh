#!/usr/bin/env bash
# Update all installed tooling. Idempotent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source_brew_env() {
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

source_brew_env

log() {
  printf '[dotfiles] %s\n' "$*"
}

log "Updating Homebrew..."
brew update

log "Reconciling Brewfile..."
brew bundle --file="$REPO_ROOT/Brewfile"

log "Upgrading packages..."
brew upgrade

log "Cleaning up..."
brew cleanup

log "Updating uv..."
uv self update 2>/dev/null || true

log "Update complete."
