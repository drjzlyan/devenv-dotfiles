#!/usr/bin/env bash
# Validate that the dotfiles environment is set up correctly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

commands=(
  brew
  nvim
  tmux
  ghostty
  lazygit
  rg
  fd
  bat
  fzf
  delta
  starship
  direnv
  zoxide
  jq
  yq
  uv
)

symlinks=(
  "$HOME/.zshrc:$REPO_ROOT/.zshrc"
  "$HOME/.tmux.conf:$REPO_ROOT/.tmux.conf"
  "$HOME/.gitconfig:$REPO_ROOT/.gitconfig"
  "$HOME/.gitignore_global:$REPO_ROOT/.gitignore_global"
  "$HOME/.config/ghostty/config:$REPO_ROOT/config/ghostty/config"
  "$HOME/.config/starship/starship.toml:$REPO_ROOT/starship.toml"
)

fail=0

for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok] $cmd"
  else
    echo "[missing] $cmd"
    fail=1
  fi
done

for entry in "${symlinks[@]}"; do
  dst="${entry%%:*}"
  src="${entry##*:}"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "[ok] $dst -> $src"
  else
    echo "[bad link] $dst"
    fail=1
  fi
done

if [[ $fail -eq 0 ]]; then
  echo "[dotfiles] All checks passed."
  exit 0
else
  echo "[dotfiles] Some checks failed."
  exit 1
fi
