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

## Language selection

`install.sh` launches an interactive language selector after the editor config
is linked. Choose which programming languages to configure:

- **Always available**: JSON, YAML, Bash, Lua, TOML, Markdown
- **Selectable**: Python, Java, TypeScript, Go, C/C++, Rust

```bash
# Change languages at any time (non-destructive, preserves existing settings)
./scripts/languages.sh          # interactive menu
./scripts/languages.sh --list   # show current selection
./scripts/languages.sh --all    # select all + install tools
```

The selection is saved to `~/.local/share/nvim/languages.local` and the
corresponding external tools are installed automatically. See the
[nvim-config languages docs](https://github.com/drjzlyan/nvim-config/blob/main/docs/languages.md)
for the full list of tools and keymaps per language.

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
