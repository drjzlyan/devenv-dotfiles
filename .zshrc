# Homebrew (Apple Silicon + Intel fallbacks)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.local/cache}"

# User-local binaries
export PATH="$HOME/Development/dotfiles/bin:$HOME/.local/bin:$HOME/.local/share/ide-tools/bin:$HOME/.local/share/go/bin:$HOME/.local/share/cargo/bin:$PATH"

# mise
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# Default programs
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# fzf shell integration
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# Directory jumping
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Per-directory environment variables
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Aliases
alias vim="nvim"
alias vi="nvim"
alias lg="lazygit"
alias cat="bat --paging=never"
alias ls="ls -G"
alias ll="ls -la"
alias ..="cd .."
alias ...="cd ../.."

# History
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$XDG_STATE_HOME/zsh/history"
mkdir -p "$(dirname "$HISTFILE")"
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
