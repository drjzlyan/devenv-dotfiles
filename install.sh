#!/usr/bin/env bash
# Bootstrap a fresh macOS machine with the dotfiles toolchain.
# Safe to run repeatedly; all steps are idempotent.
#
# This is the from-scratch installer.  rebuild.sh builds on top of the
# setup created here (pull, relink, regenerate, sync, verify).
#
# Usage:
#   ./install.sh           # full bootstrap
#   ./install.sh --no-clone # skip cloning nvim-config (assume already present)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_ROOT"
NVIM_CONFIG_PATH="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}"
NVIM_CONFIG_REPO="${NVIM_CONFIG_REPO:-https://github.com/drjzlyan/nvim-config.git}"

XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"

CLONE_NVIM=1

for arg in "$@"; do
  case "$arg" in
    --no-clone) CLONE_NVIM=0 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

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
}

clone_nvim_config() {
  if [[ -d "$NVIM_CONFIG_PATH/.git" ]]; then
    log "nvim-config already present at $NVIM_CONFIG_PATH"
    return 0
  fi
  if [[ "$CLONE_NVIM" == 0 ]]; then
    warn "nvim-config not found at $NVIM_CONFIG_PATH and --no-clone set; skipping"
    return 0
  fi
  log "Cloning nvim-config..."
  git clone "$NVIM_CONFIG_REPO" "$NVIM_CONFIG_PATH"
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
    log "Launching language & version selection..."
    "$lang_script"
  else
    warn "Language selector not found at $lang_script"
  fi
}

sync_nvim_plugins() {
  if command -v nvim >/dev/null 2>&1; then
    log "Syncing nvim plugins..."
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
  else
    warn "nvim not found — skipping plugin sync"
  fi
}

main() {
  install_homebrew
  create_xdg_dirs
  install_packages
  install_uv
  install_mise
  clone_nvim_config
  "$REPO_ROOT/link.sh"
  select_languages
  sync_nvim_plugins
  "$REPO_ROOT/doctor.sh"

  log "Bootstrap complete."
  log "  To add more languages later: ~/Development/dotfiles/scripts/languages.sh"
  log "  To rebuild after updates: ~/Development/dotfiles/rebuild.sh"
}

main "$@"
