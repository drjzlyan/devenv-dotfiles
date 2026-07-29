# dotfiles architecture

## Goal

Provide a reproducible, idempotent way to bootstrap a macOS development
machine.

## Responsibilities

| Component | Purpose |
|-----------|---------|
| `install.sh` | From-scratch bootstrap: Homebrew, packages, uv, mise, clone nvim-config, link, language selection, plugin sync, health check |
| `rebuild.sh` | Incremental rebuild on top of an existing setup: pull, backup, relink, regenerate mise.toml, reinstall tools, sync plugins, health check |
| `link.sh` | Symlink configuration files into `$HOME` |
| `update.sh` | Routine maintenance: brew upgrade, mise upgrade, plugin sync |
| `doctor.sh` | Validate the environment |
| `Brewfile` | Single source of truth for packages and casks |
| `scripts/` | Language selector, dev session launcher, agent management, tmux command runner, backups |

## Script hierarchy

```
install.sh   ← from scratch (all steps)
  └─ rebuild.sh  ← incremental (assumes install.sh has run)
       └─ update.sh  ← routine maintenance (assumes install.sh has run)
```

- `install.sh` sets up everything from a fresh machine.
- `rebuild.sh` re-applies the setup after pulling updates, preserving
  language selection, git identity, and nvim state.
- `update.sh` keeps packages and runtimes current without re-linking.

## Idempotency

All scripts are safe to run multiple times:

- `install.sh` skips already-installed components and existing symlinks.
- `rebuild.sh` preserves `languages.local`, `~/.gitconfig.local`, nvim
  sessions/plugins, and mise runtimes.
- `link.sh` re-links existing symlinks and backs up real files.
- `update.sh` updates and reconciles the Brewfile.

## Separation of concerns

- Machine-level tools live in `dotfiles`.
- Editor-specific configuration lives in `nvim-config`.
