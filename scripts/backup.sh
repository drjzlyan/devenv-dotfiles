#!/usr/bin/env bash
# Backup all files that link.sh would overwrite.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"

files=(
  "$HOME/.zshrc"
  "$HOME/.tmux.conf"
  "$HOME/.gitconfig"
  "$HOME/.gitignore_global"
  "$HOME/.config/ghostty/config"
  "$HOME/.config/starship/starship.toml"
)

for f in "${files[@]}"; do
  if [[ -e "$f" && ! -L "$f" ]]; then
    cp -R "$f" "$BACKUP_DIR/"
    echo "[backup] $f"
  fi
done

echo "[backup] Wrote backups to $BACKUP_DIR"
