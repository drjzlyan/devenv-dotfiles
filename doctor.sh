#!/usr/bin/env bash
# Validate that the dotfiles environment is set up correctly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_PATH="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}"

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
  local mismatch=0
  if has_language "python"; then
    check_version "basedpyright" "" "basedpyright --version" || mismatch=1
    check_version "ruff" "" "ruff --version" || mismatch=1
  fi
  if has_language "java"; then
    check_version "jdtls" "" "jdtls --version" || mismatch=1
  fi
  return "$mismatch"
}

# ---------------------------------------------------------------------------
# Language selection helpers (reads key=value format)
# ---------------------------------------------------------------------------

LANGUAGES_FILE="${LANGUAGES_FILE:-$HOME/.local/share/nvim/languages.local}"
selected_languages=()
declare -A selected_versions=()
if [[ -f "$LANGUAGES_FILE" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    local_lang="${line%%=*}"
    local_ver="${line#*=}"
    selected_languages+=("$local_lang")
    selected_versions["$local_lang"]="$local_ver"
  done < "$LANGUAGES_FILE"
fi

has_language() {
  local lang="$1"
  for s in "${selected_languages[@]:-}"; do
    [[ "$s" == "$lang" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Check language-specific tools
# ---------------------------------------------------------------------------

check_language_tools() {
  if [[ ${#selected_languages[@]} -eq 0 ]]; then
    echo "[info] No languages selected. Run: ~/Development/dotfiles/scripts/languages.sh"
    return 0
  fi

  for lang in "${selected_languages[@]}"; do
    local ver="${selected_versions[$lang]:-?}"
    echo ""
    echo "--- $lang (v$ver) ---"
    case "$lang" in
      python)
        check_cmd "python3" "python3 --version"
        check_cmd "basedpyright" "basedpyright --version"
        check_cmd "ruff" "ruff --version"
        ;;
      java)
        check_cmd "java" "java -version 2>&1"
        check_cmd "jdtls" "jdtls --version"
        check_cmd "mvn" "mvn --version"
        ;;
      typescript)
        check_cmd "node" "node --version"
        check_cmd "typescript-language-server" "typescript-language-server --version"
        check_cmd "prettier" "prettier --version"
        ;;
      go)
        check_cmd "go" "go version"
        check_cmd "gopls" "gopls version"
        ;;
      cpp)
        check_cmd "clangd" "clangd --version"
        check_cmd "clang-format" "clang-format --version"
        ;;
      rust)
        check_cmd "rustc" "rustc --version"
        check_cmd "cargo" "cargo --version"
        check_cmd "rust-analyzer" "rust-analyzer --version"
        ;;
      *)
        echo "[warn] Unknown language: $lang"
        ;;
    esac
  done
}

check_cmd() {
  local name="$1"
  local cmd="$2"
  if command -v "$name" >/dev/null 2>&1; then
    local ver
    ver=$($cmd 2>&1 | head -n 1)
    echo "[ok] $name ($ver)"
  else
    echo "[missing] $name"
  fi
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
# (checked based on language selection above)

check_language_tools

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
