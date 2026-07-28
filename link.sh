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

# Create or repair a repo-internal symlink with a relative target so it
# stays portable across machines. Not recorded in the manifest because
# unlink.sh only reverses $HOME links, not repo-internal ones.
link_internal() {
  local src="$1"   # relative path from the link's directory, e.g. "../scripts/dev.sh"
  local dst="$2"   # path relative to REPO_ROOT, e.g. "bin/dev"

  local dst_abs="$REPO_ROOT/$dst"
  if [[ -L "$dst_abs" && "$(readlink "$dst_abs")" == "$src" ]]; then
    echo "[link] $dst is already linked"
    return 0
  fi

  if [[ -e "$dst_abs" && ! -L "$dst_abs" ]]; then
    local backup
    backup="$dst_abs.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dst_abs" "$backup"
    echo "[link] Backed up existing $dst to $backup"
  fi

  if [[ -L "$dst_abs" ]]; then
    rm "$dst_abs"
  fi

  mkdir -p "$(dirname "$dst_abs")"
  ln -s "$src" "$dst_abs"
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

  link_internal "../scripts/dev.sh" "bin/dev"
  link_internal "../scripts/ide-agent.sh" "bin/ide-agent"
  link_internal "../scripts/project-init.sh" "bin/project-init"
  link_internal "../rebuild.sh" "bin/rebuild"

  echo "[link] Done."
}

main "$@"
