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
```

`install.sh` is a full from-scratch bootstrap: it installs Homebrew, packages,
uv, and mise, clones [`nvim-config`](https://github.com/drjzlyan/nvim-config),
links all dotfiles, launches the language selector, syncs nvim plugins, and
runs a health check. It is idempotent — running it again only fills in
missing pieces.

Optional flags:

| Flag | Effect |
|------|--------|
| `--no-clone` | Skip cloning nvim-config (use if already cloned manually) |
| `--reselect` | Re-run the language selector even if a selection already exists |

## Update

```bash
./update.sh
```

Updates Homebrew, upgrades installed packages, re-applies the Brewfile, runs
`uv self update`, upgrades all mise-managed runtimes (`mise upgrade`), and
runs `nvim-config/scripts/update-tools.sh` to refresh external Neovim tools.

## Rebuild

After pulling updates (or when you want to re-apply the full setup without
losing your existing configuration):

```bash
./rebuild.sh              # pull, relink, regenerate, reinstall, verify
./rebuild.sh --no-pull    # use local changes without pulling
./rebuild.sh --dry-run    # preview what would happen
```

Rebuild preserves your language selection (`languages.local`), Git identity
(`~/.gitconfig.local`), nvim sessions/plugins, and mise runtimes. It:
1. Pulls latest changes for both repos
2. Backs up any non-symlinked config files
3. Re-links all dotfiles (idempotent)
4. Regenerates `mise.toml` from existing language selection
5. Reinstalls language tools (idempotent)
6. Syncs nvim plugins (`:Lazy! sync`)
7. Runs a health check

## Health check

```bash
./doctor.sh
```

Checks that expected tools and symlinks are in place. Verifies: core CLI tools,
Ghostty cask, symlink correctness for all dotfiles, `dev.sh` executability, and
per-language tooling driven by `languages.local`. A failing check shows the
missing item; a passing check shows nothing.

## Directory layout

```
dotfiles/
├── Brewfile                    # Homebrew packages and casks
├── install.sh                  # First-time machine bootstrap
├── update.sh                   # Maintenance / upgrades
├── rebuild.sh                  # Re-apply setup after pulling updates
├── link.sh                     # Symlink dotfiles into $HOME
├── unlink.sh                   # Reverse all symlinks (restores backups)
├── doctor.sh                   # Health check
├── mise.toml                   # Runtime versions (auto-generated; do not edit)
├── .zshrc                      # Shell configuration
├── .tmux.conf                  # tmux configuration
├── .gitconfig                  # Git defaults
├── .gitignore_global           # Global ignore patterns
├── starship.toml               # Starship prompt
├── config/ghostty/config       # Ghostty terminal config
├── config/lazygit/config.yml   # Lazygit configuration
├── bin/nvim-edit               # Open a file in the nvim tmux pane
├── scripts/
│   ├── dev.sh          # Launch tmux IDE session
│   ├── ide-agent.sh    # In-session agent management CLI
│   ├── ide-run.sh      # Run commands in the tmux build/test pane
│   ├── languages.sh    # Interactive language/version selector
│   ├── project-init.sh # Project scaffolding tool
│   ├── backup.sh       # Backup non-symlinked config files
│   ├── relink.sh       # Remove and re-apply all symlinks
│   └── macos-defaults.sh # macOS system defaults
└── docs/                       # Documentation
```

## Language and version selection

`install.sh` launches an interactive language selector after the editor config
is linked. Choose which programming languages to configure **and which runtime
versions to install** — versions are queried dynamically from `mise ls-remote`:

- **Always available**: JSON, YAML, Bash, Lua, TOML, Markdown
- **Selectable**: Python, Java, TypeScript, Go, C/C++, Rust

```bash
# Interactive menu — choose languages and their versions (non-destructive)
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
dev -q                  # quit / kill the existing session
```

Detected agents: crush, claude, codex, gemini, aider, copilot.

The chosen agent is saved per project directory to
`~/.local/share/nvim/ide-preferences.local`. Re-opening the same directory
with `dev` reuses the saved agent without prompting. `dev -a <agent>` both sets
the session agent and updates the saved preference.

In-session keybindings (tmux prefix is `Ctrl-a`):

| Key | Action |
|-----|--------|
| `Ctrl-a A` | Switch agent (interactive prompt) |
| `Ctrl-a N` | Cycle to next agent |
| `Ctrl-a D` | Reset layout to default (preserves nvim) |
| `Ctrl-a Q` | Kill IDE session (with confirmation) |
| `Ctrl-a P` | Create new project (prompts for `language:name`) |
| `Ctrl-a S` | Toggle synchronize-panes mode |

`scripts/ide-agent.sh` provides the same operations from the command line:

```bash
ide-agent status        # show current agent, available agents, and saved pref
ide-agent switch        # interactive switch (from within tmux)
ide-agent next          # cycle to next agent
ide-agent prev          # cycle to previous agent
ide-agent reset         # reset pane layout to default
ide-agent prefs         # show contents of the preferences file
ide-agent clear-pref    # remove saved agent preference for current project
```

`scripts/ide-run.sh` (available as `ide-run` on `$PATH`) routes shell commands
to the session's `build/test` pane, creating the pane on demand if it is
missing. Neovim task/test keymaps use it automatically when running inside
tmux, so build and test output stays in the tmux pane instead of a separate
editor terminal:

```bash
ide-run 'make test'            # run in the build/test pane
ide-run -d /path 'go test ./...'
ide-run --focus                # just focus the build/test pane
```

All IDE panes export `EDITOR=nvim-edit VISUAL=nvim-edit GIT_EDITOR=nvim-edit`,
so anything that opens an editor (coding agents, `git commit`, lazygit) reuses
the Neovim instance running in the editor pane instead of spawning a new one.

## Project scaffolding

`scripts/project-init.sh` (available as `project-init` on `$PATH`) creates a
language-appropriate project scaffold, runs `git init`, and — if inside a tmux
session — opens the project in a new dev window.

```bash
project-init <language> <name> [parent_dir]
```

| Language | Example | What it creates |
|----------|---------|-----------------|
| `python` | `project-init python myapp` | `pyproject.toml`, `src/myapp/`, `tests/`, `.gitignore` |
| `java` | `project-init java com.example.myapp` | `pom.xml`, Maven standard layout, JUnit 5 test |
| `typescript` | `project-init typescript myapp` | `package.json`, `tsconfig.json`, `src/`, `test/`, installs npm deps |
| `go` | `project-init go github.com/user/myapp` | `go.mod` (or `go mod init`), `cmd/<name>/main.go` |
| `cpp` | `project-init cpp myapp` | `CMakeLists.txt`, `src/main.cpp`, `tests/test_main.cpp` |
| `rust` | `project-init rust myapp` | `cargo init` (or bare `Cargo.toml` + `src/main.rs`) |

From inside a tmux session, `Ctrl-a P` prompts for `language:name` and runs
`project-init` directly (e.g. type `python:myapp` at the prompt).

## Shell environment

`.zshrc` sets up the following tools automatically if they are installed:

| Tool / alias | What it does |
|--------------|-------------|
| `vim`, `vi` | Redirected to `nvim` |
| `lg` | `lazygit` shortcut |
| `cat` | `bat --paging=never` (syntax-highlighted output) |
| `ls` | Colorized (`ls -G`) |
| `ll` | `ls -la` |
| `..` / `...` | Jump up one / two directories |
| `z <dir>` | Smart directory jump via `zoxide` |
| `fzf` | Shell integration: `Ctrl-R` history search, `Ctrl-T` file picker, `Alt-C` directory jump |
| `direnv` | Per-directory `.envrc` environment variable loading |
| `starship` | Prompt |

History is stored at `$XDG_STATE_HOME/zsh/history` with 100 000 lines, shared
across sessions, and deduplicated.

PATH additions (in order): `~/Development/dotfiles/bin`, `~/.local/bin`,
`~/.local/share/ide-tools/bin`, Go bin (`~/.local/share/go/bin`), Cargo bin
(`~/.local/share/cargo/bin`).

## Terminal (Ghostty)

`config/ghostty/config` sets:

- **Font**: JetBrainsMono Nerd Font, size 13
- **Theme**: `tokyonight`
- **Scrollback**: 100 000 lines
- **Mouse**: hidden while typing
- **macOS titlebar**: tabs style
- **`Cmd+D`**: split right
- **`Cmd+Shift+D`**: split down

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
