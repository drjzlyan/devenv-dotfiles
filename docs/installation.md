# Installation guide

## 1. Clone the repositories

```bash
git clone https://github.com/drjzlyan/devenv-dotfiles.git
git clone https://github.com/drjzlyan/nvim-config.git
```

## 2. Bootstrap the machine

```bash
cd dotfiles
./install.sh
```

This installs Homebrew, all command-line tools, Ghostty, tmux, the
JetBrainsMono Nerd Font, Temurin JDKs, and uv. It also calls `link.sh`
internally, so symlinks are created as part of this step — no need to run
`link.sh` separately on a fresh install.

Optional flags:

| Flag | Effect |
|------|--------|
| `--no-clone` | Skip cloning nvim-config (use if already cloned) |
| `--reselect` | Re-run the language selector even if already configured |

To refresh symlinks after pulling updates without running the full bootstrap:

```bash
./link.sh
```

## 3. Configure Git user

Create `~/.gitconfig.local`:

```ini
[user]
    name = Your Name
    email = you@example.com
```

## 4. Install Neovim configuration

```bash
cd ../nvim-config
# Neovim will bootstrap lazy.nvim and install plugins on first launch
nvim
```

## 5. Verify

```bash
cd ../dotfiles
./doctor.sh
```

Run `./update.sh` regularly to keep tools current.
