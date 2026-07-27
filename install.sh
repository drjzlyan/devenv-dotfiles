#!/usr/bin/env bash
# Bootstrap a fresh macOS machine with the dotfiles toolchain.
# Safe to run repeatedly; all steps are idempotent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_ROOT"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

source_brew_env() {
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    source_brew_env
  else
    log "Homebrew already installed"
    source_brew_env
  fi
}

create_xdg_dirs() {
  log "Creating XDG base directories..."
  mkdir -p "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

  if [[ -d "$HOME/.local" ]]; then
    chown -R "$USER" "$HOME/.local" 2>/dev/null || true
    chmod 700 "$HOME/.local" 2>/dev/null || true
  fi
}

install_packages() {
  log "Installing Homebrew bundle..."
  if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
    warn "Brewfile not found at $DOTFILES_DIR/Brewfile"
    return 1
  fi
  brew bundle --file="$DOTFILES_DIR/Brewfile"
}

install_uv() {
  if ! command -v uv >/dev/null 2>&1; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
  else
    log "uv already installed"
  fi
}

main() {
  install_homebrew
  create_xdg_dirs
  install_packages
  install_uv

  log "Bootstrap complete."
  log "Run './link.sh' to symlink dotfiles."
  log "Run './doctor.sh' to verify the installation."
}

main "$@"
