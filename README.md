# dotfiles

Machine bootstrap for a terminal-first macOS development environment.

## Purpose

This repository turns a fresh macOS machine into a productive development box.
It installs package managers, tools, fonts, JVMs, and symlinks configuration
files. It deliberately contains no editor-specific configuration — that lives
in [`nvim-config`](https://github.com/example/nvim-config).

## Prerequisites

- macOS (Apple Silicon or Intel)
- Internet connection
- `git` (the installer will install it if missing)

## Installation

```bash
git clone https://github.com/example/dotfiles.git
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
├── scripts/              # Utility scripts
└── docs/                 # Documentation
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
