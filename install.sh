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

install_mise() {
  if ! command -v mise >/dev/null 2>&1; then
    log "Installing mise..."
    brew install mise
  fi
  if [[ -f "$REPO_ROOT/mise.toml" ]]; then
    log "Installing mise runtimes..."
    mise install
  fi
}

install_nvim_config() {
  local nvim_config_path="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}"
  if [[ ! -d "$nvim_config_path" ]]; then
    warn "nvim-config not found at $nvim_config_path; skipping editor config link"
    return 0
  fi
  local target="$HOME/.config/nvim"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup="$target.bak.$(date +%s)"
    log "Backing up existing $target to $backup"
    mv "$target" "$backup"
  fi
  if [[ -L "$target" ]]; then
    rm "$target"
  fi
  ln -s "$nvim_config_path" "$target"
  log "Linked nvim-config -> $target"
}

install_external_tools() {
  local tool_script="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}/scripts/install-tools.sh"
  if [[ -x "$tool_script" ]]; then
    log "Running external tool installer..."
    "$tool_script"
  else
    warn "External tool installer not found at $tool_script"
  fi
}

select_languages() {
  local lang_script="$REPO_ROOT/scripts/languages.sh"
  if [[ -x "$lang_script" ]]; then
    local langs_file="$HOME/.local/share/nvim/languages.local"
    if [[ -f "$langs_file" ]]; then
      log "Language selection already exists; skipping interactive menu."
      log "  To change: $lang_script"
      return 0
    fi
    log "Launching language selection..."
    "$lang_script"
  else
    warn "Language selector not found at $lang_script"
  fi
}

main() {
  install_homebrew
  create_xdg_dirs
  install_packages
  install_uv
  install_mise
  install_nvim_config
  select_languages
  install_external_tools
  "$REPO_ROOT/link.sh"
  "$REPO_ROOT/doctor.sh"

  log "Bootstrap complete."
  log "  To add more languages later: ~/Development/dotfiles/scripts/languages.sh"
}

main "$@"
