#!/usr/bin/env bash
# Symlink dotfiles into $HOME. Idempotent and non-destructive
# (existing files are backed up first).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_ROOT"

link_file() {
  local src="$1"
  local dst="$2"

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      echo "[link] $dst is already linked"
      return 0
    fi
    rm "$dst"
  fi

  if [[ -e "$dst" ]]; then
    local backup
    backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    echo "[link] Backed up existing $dst to $backup"
  fi

  ln -s "$src" "$dst"
  echo "[link] Linked $dst -> $src"
}

main() {
  link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
  link_file "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
  link_file "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
  link_file "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"

  mkdir -p "$HOME/.config/ghostty"
  link_file "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"

  mkdir -p "$HOME/.config/starship"
  link_file "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship/starship.toml"

  echo "[link] Done."
}

main "$@"
