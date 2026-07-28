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
JetBrainsMono Nerd Font, Temurin JDKs, and uv.

## 3. Symlink configuration

```bash
./link.sh
```

The script backs up any existing files and creates symlinks from `$HOME`.

## 4. Configure Git user

Create `~/.gitconfig.local`:

```ini
[user]
    name = Your Name
    email = you@example.com
```

## 5. Install Neovim configuration

```bash
cd ../nvim-config
# Neovim will bootstrap lazy.nvim and install plugins on first launch
nvim
```

## 6. Verify

```bash
cd ../dotfiles
./doctor.sh
```

Run `./update.sh` regularly to keep tools current.
