#!/usr/bin/env bash
# Validate that the dotfiles environment is set up correctly.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_PATH="${NVIM_CONFIG_PATH:-$REPO_ROOT/../nvim-config}"

fail=0

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
# Tool checks
# ---------------------------------------------------------------------------

check_cmd() {
  local name="$1"
  local cmd="$2"
  if command -v "$name" >/dev/null 2>&1; then
    local ver
    ver=$(eval "$cmd" 2>&1 | head -n 1 || true)
    echo "[ok] $name ($ver)"
  else
    echo "[missing] $name"
    fail=1
  fi
}

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
        check_cmd "jdtls" "jdtls --help 2>&1 | head -1"
        check_cmd "mvn" "mvn --version"
        # JDK sanity check (managed by mise) — verify ALL selected versions
        if command -v mise >/dev/null 2>&1; then
          local java_vers="${selected_versions[java]:-}"
          if [[ -n "$java_vers" ]]; then
            local jdk_ver
            IFS=',' read -ra jdk_ver <<< "$java_vers"
            for v in "${jdk_ver[@]}"; do
              v=$(echo "$v" | tr -d ' ')
              [[ -z "$v" ]] && continue
              local jdk_path
              jdk_path=$(mise where "java@${v}" 2>/dev/null || true)
              if [[ -n "$jdk_path" && -d "$jdk_path" ]]; then
                echo "[ok] JDK ${v} via mise ($jdk_path)"
              else
                echo "[missing] JDK ${v} (run: mise install java@${v})"
                fail=1
              fi
            done
          fi
        fi
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

# ---------------------------------------------------------------------------
# Core tool checks
# ---------------------------------------------------------------------------

commands=(
  brew
  nvim
  tmux
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

for cmd in "${commands[@]}"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok] $cmd"
  else
    echo "[missing] $cmd"
    fail=1
  fi
done

# Cask apps (GUI tools not on PATH)
cask_apps=(
  ghostty
)

for app in "${cask_apps[@]}"; do
  if command -v brew >/dev/null 2>&1 && brew list --cask "$app" >/dev/null 2>&1; then
    echo "[ok] $app (cask)"
  else
    echo "[missing] $app (run: brew install --cask $app)"
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

# ---------------------------------------------------------------------------
# Language-specific tool checks
# ---------------------------------------------------------------------------

check_language_tools

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

if [[ $fail -eq 0 ]]; then
  echo "[dotfiles] All required checks passed."
  exit 0
else
  echo "[dotfiles] Some required checks failed."
  exit 1
fi
