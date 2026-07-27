#!/usr/bin/env bash
# Remove existing dotfile symlinks and re-run link.sh.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

files=(
  "$HOME/.zshrc"
  "$HOME/.tmux.conf"
  "$HOME/.gitconfig"
  "$HOME/.gitignore_global"
  "$HOME/.config/ghostty/config"
  "$HOME/.config/starship/starship.toml"
)

for f in "${files[@]}"; do
  if [[ -L "$f" ]]; then
    rm "$f"
    echo "[relink] removed $f"
  fi
done

"$REPO_ROOT/link.sh"
