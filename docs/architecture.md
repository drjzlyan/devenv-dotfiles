# dotfiles architecture

## Goal

Provide a reproducible, idempotent way to bootstrap a macOS development
machine.

## Responsibilities

| Component | Purpose |
|-----------|---------|
| `install.sh` | Install Homebrew, packages, fonts, JVMs, and uv |
| `link.sh` | Symlink configuration files into `$HOME` |
| `update.sh` | Keep installed packages up to date |
| `doctor.sh` | Validate the environment |
| `Brewfile` | Single source of truth for packages and casks |
| `scripts/` | Optional utilities and macOS tweaks |

## Idempotency

All scripts are safe to run multiple times:

- `install.sh` skips already-installed components.
- `link.sh` re-links existing symlinks and backs up real files.
- `update.sh` updates and reconciles the Brewfile.

## Separation of concerns

- Machine-level tools live in `dotfiles`.
- Editor-specific configuration lives in `nvim-config`.
