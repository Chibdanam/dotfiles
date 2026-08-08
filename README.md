# Dotfiles

Personal dotfiles for a Debian 13 VPS dev environment.

## Quick Start

```bash
git clone https://github.com/YannickHerrero/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh all
```

Requires `sudo` access (used by the `apt` and `nvim` modules) and an
internet connection.

## Modular Installation

Install specific components:

```bash
./install.sh apt        # System dependencies (build-essential, curl, etc.)
./install.sh zsh        # Zsh + oh-my-posh
./install.sh tmux       # Tmux
./install.sh herdr      # Herdr terminal workspace manager
./install.sh nvim       # Neovim
./install.sh mise       # mise runtime manager
./install.sh node       # Node.js LTS + bun + pnpm + npm packages
./install.sh rust       # Rust toolchain (rustup)
./install.sh tools      # zoxide, delta, lazygit, gh, macchina, ...
./install.sh claude     # Claude Code global config + skills
./install.sh ssh        # Optional GitHub SSH key generation
./install.sh git        # Git configuration
./install.sh dotfiles   # Copy all config files
```

Or combine:

```bash
./install.sh apt zsh nvim
```

Tmux and oh-my-posh intentionally inherit colors from the SSH client terminal.

Herdr is the preferred terminal workspace manager (shell shortcut `f`); tmux is kept as a fallback (`tf`). The `herdr` module installs the binary from herdr.dev, and its config plus space sessionizer live in `config/herdr/` (copied by the `dotfiles` module). Runtime state (sockets, logs, `session.json`, worktrees) is intentionally not versioned.

GitHub SSH setup is optional. Public bootstrap downloads use HTTPS by default so a fresh shell works before adding a GitHub SSH key.

The `git` module reuses an existing global Git identity when `user.name` and `user.email` are already set, and asks for confirmation before keeping them.

The `claude` module installs user-scoped Claude Code configuration into `~/.claude/`. The default settings disable Claude attribution in commits and pull requests, allow common Git workflows without prompts, ask for approval on higher-risk commands, and block a few dangerous patterns outright. The tracked `settings.json` is the shared baseline; the installed `~/.claude/settings.json` is **generated** by merging it with `~/.claude/settings.local.json` (see below) — put durable machine preferences in the local file, not in the generated one, or the next install loses them (this includes defaults saved by `/effort`, `/model`, `/config`).

## Machine-local configuration

One branch serves every machine. Tracked config files are overwritten on each install; anything that differs per machine lives in an untracked local file that is seeded once from a template and never overwritten afterwards.

| Live file | Purpose | Template | Seeded by |
|-----------|---------|----------|-----------|
| `~/.gitconfig.local` | git identity, gh credential helpers, `[personal]` identity for `gsp` | `config/git/gitconfig.local.example` | `git` module (seed-once) |
| `~/.claude/settings.local.json` | machine Claude policy: git push / docker / curl rules, `defaultMode`, plugins, marketplaces | `config/claude/settings.local.example.json` | `claude` module (seed-once) |
| `~/.claude/CLAUDE.local.md` | machine Claude instructions (push policy), imported by `CLAUDE.md` | `config/claude/CLAUDE.local.example.md` | `claude` module (seed-once) |
| `~/.config/zsh/fuzzy-dir.local.txt` | extra sessionizer roots (herdr `f` and tmux `tf`, both `prefix + j` binds) | `config/zsh/fuzzy-dir.example.txt` | `dotfiles` module (seed-once) |
| `~/.config/zsh/.secrets.zsh` | tokens / API keys | `config/zsh/secrets.zsh.example` | manual (`cp` + `chmod 600`) |
| `~/.config/mise/config.toml` | mise tool pins, incl. extra work-only dotnet tools | — | `mise use --global` (manual) |
| `~/.config/zsh/*.zsh` (any extra file) | free-form machine-local zsh — auto-sourced by the `.zshrc` glob, never deleted by installs | — | manual |

Permission-rule merging: local `allow`/`ask`/`deny` arrays union with the baseline, and a rule promoted to `allow` locally is dropped from the baseline `ask` list. Scalar keys from the local file win. Rules deliberately absent from the baseline (`Bash(git push *)`, `Bash(docker *)`, `Bash(curl *)`) fall back to prompting until a machine takes a stance in its local file.

## What's Included

### Tools Installed

#### Shell & Terminal

| Tool | Installation | Description |
|------|--------------|-------------|
| zsh | apt | Shell with zinit plugin manager |
| oh-my-posh | curl | Prompt that inherits terminal colors |
| tmux | apt | Terminal multiplexer with TPM |
| herdr | curl | Terminal workspace manager (preferred; tmux kept as fallback) |

#### Editor

| Tool | Installation | Description |
|------|--------------|-------------|
| neovim | GitHub release | Text editor (0.11+) |

#### Runtime Managers / Toolchains

| Tool | Installation | Description |
|------|--------------|-------------|
| mise | curl | Polyglot runtime manager |
| rustup | curl | Rust toolchain installer (provides cargo, rustc, rustfmt, clippy) |

#### JavaScript

| Tool | Installation | Description |
|------|--------------|-------------|
| Node.js LTS | mise | JavaScript runtime |
| bun | mise | JavaScript runtime/bundler |
| pnpm | mise | Fast package manager |
| tree-sitter-cli | npm | Parser builder for nvim-treesitter v1 |

#### CLI Tools

| Tool | Installation | Description |
|------|--------------|-------------|
| claude code | curl | AI coding assistant |
| zoxide | mise | Smart cd |
| delta | mise | Git diff viewer |
| lazygit | mise | Git TUI |
| gh | mise | GitHub CLI |
| colorscript | git/make | shell-color-scripts; decorative blocks in snacks dashboard |
| macchina | cargo | Rust-based system info fetch (aliased to `fetch`) |
| fzf | apt | Fuzzy finder |
| eza | apt | Modern ls |
| bat | apt | Cat with syntax highlighting |
| ripgrep | apt | Fast grep |
| fd | apt | Fast find |

### Neovim Plugins

| Plugin | Role |
|--------|------|
| lazy.nvim | Plugin manager |
| blink.cmp | Completion (Rust-backed) |
| supermaven-nvim | Inline AI completions (ghost text) |
| snacks.nvim | picker, explorer, dashboard, bigfile, quickfile |
| mini.nvim | pairs, surround, statusline, tabline, icons |
| nvim-treesitter (v1 main) | Syntax highlighting + indent |
| nvim-lspconfig + mason + mason-lspconfig | LSP wiring |
| mason-tool-installer | Auto-installs stylua / prettier / shfmt |
| conform.nvim | Format-on-save |
| which-key.nvim | Keybinding hints |

**LSP servers** (auto-installed via mason): `ts_ls`, `rust_analyzer`, `lua_ls`, `bashls`.
**Formatters** (auto-installed via mason-tool-installer): `stylua`, `prettier`, `shfmt`. `rustfmt` comes from the Rust toolchain.

**Supermaven** needs a one-time activation: run `:SupermavenUseFree` in nvim (or `:SupermavenUsePro` with a Pro account) and follow the link. Inline suggestions: `<Tab>` accept, `<S-Tab>` accept word, `<C-]>` dismiss.

### Key Bindings

#### Herdr (prefix: Ctrl+A)
| Key | Action |
|-----|--------|
| `prefix + j` | Space sessionizer in a pane (select `~/dev` project, focus/create space) |
| `prefix + \|` | Split vertical |
| `prefix + -` | Split horizontal |
| `Ctrl + h/j/k/l` | Focus pane left/down/up/right |
| `prefix + r` | Resize mode (then arrows/hjkl, esc to exit) |
| `prefix + c / n / p` | New / next / previous tab |
| `prefix + 1..9` or `Alt + 1..9` | Switch to tab N |
| `prefix + Shift + g` | New git worktree |
| `prefix + Shift + o` | Open git worktree |
| `Ctrl + b` | Toggle sidebar |

#### Tmux (prefix: Ctrl+A)
| Key | Action |
|-----|--------|
| `prefix + \|` | Split vertical |
| `prefix + -` | Split horizontal |
| `prefix + j` | Sessionizer popup (select project, create/attach session) |
| `prefix + r` | Reload config |
| `Ctrl + h/j/k/l` | Navigate panes |
| `Alt + 1-5` | Switch windows |

#### Neovim (leader: Space)
| Key | Action |
|-----|--------|
| `Space + Space` | Find files (snacks.picker) |
| `Space + sg` | Live grep (snacks.picker) |
| `Space + e` | Toggle file explorer (snacks.explorer, right-side) |
| `Space + bd` | Close buffer |
| `Space + o` | Toggle statusline visibility |
| `Shift + h/l` | Previous/next buffer (also switches tab in mini.tabline) |
| `gd` | Go to definition (LSP) |
| `gr` | Find references (LSP) |
| `K` | Hover docs (LSP) |
| `Space + ca` | Code action (LSP) |
| `Space + rn` | Rename symbol (LSP) |

#### Zsh
| Key | Action |
|-----|--------|
| `f` | Herdr space sessionizer (select `~/dev` project, focus/create space with Claude/run/vim tabs) |
| `tf` | Tmux sessionizer (fallback; select project, create/attach session) |
| `ff` | Fuzzy find files, open in nvim |
| `z <dir>` | Smart cd with zoxide |

## Directory Structure

```
dotfiles/
├── install.sh              # Main install script
├── config/
│   ├── git/.gitconfig
│   ├── claude/             # Claude Code global config and skills
│   ├── nvim/               # Neovim config
│   ├── ohmyposh/zen.toml   # Prompt theme
│   ├── herdr/              # Herdr config + space sessionizer
│   ├── tmux/tmux.conf
│   └── zsh/                # Zsh configs
├── scripts/
│   └── modules/            # Install modules
```

## Troubleshooting

If an install step dies partway through (network blip, transient apt
failure, etc.), it's safe to just re-run:

```bash
./install.sh all          # picks up where it left off
./install.sh <module>     # or re-run a single module
```

Every module is idempotent — already-installed tools are detected via
`command -v` and skipped, and `./install.sh dotfiles` sweeps stale
configs before copying so removing a plugin upstream actually
removes it from `~/.config/nvim`.

`gh auth login` is interactive and must be run manually.

## Requirements

- Debian 13
- sudo access
- Internet connection

## License

MIT
