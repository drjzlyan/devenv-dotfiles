# dotfiles

Machine bootstrap for a terminal-first macOS development environment.

## Purpose

This repository turns a fresh macOS machine into a productive development box.
It installs package managers, tools, fonts, JVMs, and symlinks configuration
files. It deliberately contains no editor-specific configuration — that lives
in [`nvim-config`](https://github.com/drjzlyan/nvim-config).

## Prerequisites

- macOS (Apple Silicon or Intel)
- Internet connection
- `git` (the installer will install it if missing)

## Installation

```bash
git clone https://github.com/drjzlyan/devenv-dotfiles.git
cd dotfiles
./install.sh
./link.sh
```

`install.sh` is idempotent: running it again only installs missing pieces.

## Update

```bash
./update.sh
```

This updates Homebrew, upgrades installed packages, and re-applies the Brewfile.

## Health check

```bash
./doctor.sh
```

Checks that expected tools and symlinks are in place.

## Directory layout

```
dotfiles/
├── Brewfile              # Homebrew packages and casks
├── install.sh            # First-time machine bootstrap
├── update.sh             # Maintenance / upgrades
├── link.sh               # Symlink dotfiles into $HOME
├── doctor.sh             # Health check
├── .zshrc                # Shell configuration
├── .tmux.conf            # tmux configuration
├── .gitconfig            # Git defaults
├── .gitignore_global     # Global ignore patterns
├── starship.toml         # Starship prompt
├── config/ghostty/config # Ghostty terminal config
├── scripts/              # Utility scripts (languages.sh, dev.sh, backup.sh, …)
└── docs/                 # Documentation
```

## Language and version selection

`install.sh` launches an interactive language selector after the editor config
is linked. Choose which programming languages to configure **and which runtime
versions to install** — versions are queried dynamically from `mise ls-remote`:

- **Always available**: JSON, YAML, Bash, Lua, TOML, Markdown
- **Selectable**: Python, Java, TypeScript, Go, C/C++, Rust

```bash
# Interactive menu — toggle languages, change versions (non-destructive)
./scripts/languages.sh          # interactive menu
./scripts/languages.sh --list   # show current selection with versions
./scripts/languages.sh --all    # select all (latest stable) + install
```

The selection is saved to `~/.local/share/nvim/languages.local` in `key=value`
format. `mise.toml` is generated automatically from the selection — no static
version lists are stored. See the
[nvim-config languages docs](https://github.com/drjzlyan/nvim-config/blob/main/docs/languages.md)
for the full list of tools and keymaps per language.

## Dev session and coding agents

`scripts/dev.sh` launches a tmux session with panes for Neovim, an AI coding
agent, and a build/test shell. Agents are auto-detected from `$PATH`:

```bash
dev                     # auto-detect agents, prompt if multiple
dev -a claude           # use a specific agent
dev -a none             # no agent, just a shell
dev -k                  # kill existing session and recreate
```

Detected agents: crush, claude, codex, gemini, aider, copilot.

In-session keybindings (tmux prefix is `Ctrl-a`):

| Key | Action |
|-----|--------|
| `Ctrl-a A` | Switch agent (interactive prompt) |
| `Ctrl-a N` | Cycle to next agent |
| `Ctrl-a D` | Reset layout to default (preserves nvim) |

`scripts/ide-agent.sh` provides the same operations from the command line:

```bash
ide-agent status     # show current agent and available agents
ide-agent switch     # interactive switch (from within tmux)
ide-agent next       # cycle to next agent
ide-agent reset      # reset layout
```

## Philosophy

- **Idempotent**: running scripts repeatedly is safe.
- **Modular**: each file has a single responsibility.
- **Reproducible**: the Brewfile pins the tool list.
- **Editor-agnostic**: editor configuration is in a separate repository.

## Manual steps after install

Create `~/.gitconfig.local` with your name and email:

```ini
[user]
    name = Your Name
    email = you@example.com
```

Restart your terminal or run `source ~/.zshrc`.
