#!/usr/bin/env bash
# Validate that the dotfiles environment is set up correctly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_PATH="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}"
TOOLS_LOCK="$NVIM_CONFIG_PATH/scripts/tools.lock"

extract_version() {
  local output="$1"
  echo "$output" | sed -n 's/.*\([0-9]\+\.[0-9]\+\(\.[0-9]\+\)\).*/\1/p' | head -n 1
}

check_version() {
  local name="$1"
  local expected="$2"
  local cmd="$3"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "[missing] $name"
    return 1
  fi
  local actual
  actual=$(extract_version "$($cmd 2>&1)")
  if [[ -z "$expected" ]]; then
    echo "[ok] $name ($actual)"
    return 0
  fi
  if [[ "$actual" == "$expected" || "$actual" == "$expected"* ]]; then
    echo "[ok] $name ($actual)"
    return 0
  fi
  echo "[version mismatch] $name: expected $expected, found $actual"
  return 1
}

check_tools_lock() {
  if [[ ! -f "$TOOLS_LOCK" ]]; then
    echo "[warn] tools.lock not found at $TOOLS_LOCK"
    return 0
  fi
  source "$TOOLS_LOCK"
  local mismatch=0
  check_version "basedpyright" "${BASEDPYRIGHT_VERSION:-}" "basedpyright --version" || mismatch=1
  check_version "ruff" "${RUFF_VERSION:-}" "ruff --version" || mismatch=1
  check_version "jdtls" "${JDTLS_VERSION:-}" "jdtls --version" || mismatch=1
  return "$mismatch"
}

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
  mise
)

# Check dev script is executable
if [[ -x "$REPO_ROOT/scripts/dev.sh" ]]; then
  echo "[ok] dev (session launcher)"
else
  echo "[missing] dev (run: chmod +x scripts/dev.sh)"
  fail=1
fi

symlinks=(
  "$HOME/.config/nvim:$NVIM_CONFIG_PATH"
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

# Optional development tools for the Neovim configuration
optionals=(
  jdtls
  basedpyright
  ruff
  google-java-format
)

for cmd in "${optionals[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok] $cmd (optional)"
  else
    echo "[missing] $cmd (optional — install with brew if needed)"
  fi
done

check_tools_lock || fail=1

# JDK sanity check (managed by mise)
if command -v mise >/dev/null 2>&1; then
  for v in 17 11 8; do
    jdk_path=$(mise where java@"$v" 2>/dev/null || true)
    if [[ -n "$jdk_path" && -d "$jdk_path" ]]; then
      echo "[ok] JDK $v via mise ($jdk_path)"
    else
      echo "[missing] JDK $v (run: mise install java@$v)"
    fi
  done
fi

if command -v java >/dev/null 2>&1; then
  echo "[ok] java ($(java -version 2>&1 | head -n 1))"
else
  echo "[missing] java"
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo "[dotfiles] All required checks passed."
  exit 0
else
  echo "[dotfiles] Some required checks failed."
  exit 1
fi
