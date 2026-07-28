#!/usr/bin/env bash
# Symlink dotfiles into $HOME. Idempotent and non-destructive
# (existing files are backed up first).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_ROOT"
MANIFEST_DIR="$HOME/.local/share/dotfiles"
MANIFEST="$MANIFEST_DIR/manifest"

mkdir -p "$MANIFEST_DIR"
: > "$MANIFEST"

link_file() {
  local src="$1"
  local dst="$2"
  local backup_path=""

  if [[ ! -e "$src" ]]; then
    echo "[link] Source missing: $src"
    return 1
  fi

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      echo "[link] $dst is already linked"
      return 0
    fi
    rm "$dst"
  fi

  if [[ -e "$dst" ]]; then
    backup_path="$dst.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup_path"
    echo "[link] Backed up existing $dst to $backup_path"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "$dst|$backup_path" >> "$MANIFEST"
  echo "[link] Linked $dst -> $src"
}

main() {
  link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
  link_file "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
  link_file "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
  link_file "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"

  link_file "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
  link_file "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship/starship.toml"

  if [[ -d "$DOTFILES_DIR/../nvim-config" ]]; then
    link_file "$DOTFILES_DIR/../nvim-config" "$HOME/.config/nvim"
  fi

  echo "[link] Done."
}

main "$@"
