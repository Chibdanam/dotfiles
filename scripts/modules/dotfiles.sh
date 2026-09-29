#!/bin/bash
set -euo pipefail
# Copy all dotfiles to their appropriate locations

_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$_MODULE_DIR")")"

copy_dotfiles() {
    echo "Copying dotfiles..."
    
    # Create necessary directories
    mkdir -p "$HOME/.config/nvim/lua/plugins"
    mkdir -p "$HOME/.config/ohmyposh"
    mkdir -p "$HOME/.config/tmux"
    mkdir -p "$HOME/.config/herdr"
    mkdir -p "$HOME/.config/zsh"
    mkdir -p "$HOME/.config/lazygit"
    mkdir -p "$HOME/.config/rtk"
    mkdir -p "$HOME/.config/opencode"
    mkdir -p "$HOME/dev"
    
    # Copy nvim config
    echo "  - Neovim config"
    cp "$DOTFILES_DIR/config/nvim/init.lua" "$HOME/.config/nvim/"
    cp "$DOTFILES_DIR/config/nvim/stylua.toml" "$HOME/.config/nvim/"
    cp "$DOTFILES_DIR/config/nvim/lua/"*.lua "$HOME/.config/nvim/lua/"
    # Mirror the repo's plugin directory: drop stale specs that were removed
    # upstream before copying so lazy.nvim doesn't keep loading them.
    rm -f "$HOME/.config/nvim/lua/plugins/"*.lua
    cp "$DOTFILES_DIR/config/nvim/lua/plugins/"*.lua "$HOME/.config/nvim/lua/plugins/"
    rm -f "$HOME/.config/nvim/lua/plugins.lua"
    
    # Copy zsh config under XDG_CONFIG_HOME/zsh; ~/.zshenv points zsh there.
    echo "  - Zsh config"
    cp "$DOTFILES_DIR/config/zsh/.zshenv" "$HOME/.zshenv"
    cp "$DOTFILES_DIR/config/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"
    # Mirror the repo: .zshrc sources every *.zsh, so a file removed upstream
    # would keep loading. The glob skips dotfiles, .secrets.zsh survives.
    rm -f "$HOME/.config/zsh/"*.zsh
    cp "$DOTFILES_DIR/config/zsh/"*.zsh "$HOME/.config/zsh/"
    # Clean up any leftovers from the pre-XDG layout.
    rm -f "$HOME/.zshrc"
    rm -rf "$HOME/.zsh"

    # Monorepo search roots for f(): seeded once from the template, then left
    # alone forever so machine-local edits survive every install/sync.
    local fuzzy_roots="$HOME/.config/zsh/fuzzy-dir.local.txt"
    if [ ! -e "$fuzzy_roots" ]; then
        cp "$DOTFILES_DIR/config/zsh/fuzzy-dir.example.txt" "$fuzzy_roots"
        echo "  - Seeded $fuzzy_roots (edit to add monorepo roots)"
    else
        echo "  - Kept existing $fuzzy_roots"
    fi
    
    # Copy tmux config
    echo "  - Tmux config"
    cp "$DOTFILES_DIR/config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    cp "$DOTFILES_DIR/config/tmux/sessionizer.sh" "$HOME/.config/tmux/sessionizer.sh"
    chmod +x "$HOME/.config/tmux/sessionizer.sh"

    # Copy herdr config. herdr is the preferred multiplexer (f()); tmux above is
    # kept as a fallback (tf()). Runtime state (session.json, *.sock, *.log) is
    # left untouched — only the config.toml and sessionizer are versioned.
    echo "  - Herdr config"
    cp "$DOTFILES_DIR/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"
    cp "$DOTFILES_DIR/config/herdr/sessionizer.sh" "$HOME/.config/herdr/sessionizer.sh"
    chmod +x "$HOME/.config/herdr/sessionizer.sh"

    # Copy oh-my-posh config
    echo "  - Oh My Posh config"
    cp "$DOTFILES_DIR/config/ohmyposh/zen.toml" "$HOME/.config/ohmyposh/"

    echo "  - Lazygit config"
    cp "$DOTFILES_DIR/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"

    # rtk's filters.toml is its own untouched template: only config.toml is ours
    echo "  - rtk config"
    cp "$DOTFILES_DIR/config/rtk/config.toml" "$HOME/.config/rtk/config.toml"

    # opencode writes its own package.json/node_modules here: only the config
    # is ours. It reads the DGX key from ~/.config/dgx/token and refuses to
    # start if that file is missing, so seed an empty one (fill it by hand).
    echo "  - opencode config"
    cp "$DOTFILES_DIR/config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
    if [ ! -e "$HOME/.config/dgx/token" ]; then
        mkdir -p "$HOME/.config/dgx"
        install -m 600 /dev/null "$HOME/.config/dgx/token"
        echo "  - Seeded empty ~/.config/dgx/token (paste the DGX gateway key)"
    fi

    # init-vscode: VS Code attach-debugging for a .NET repo (.vscode/launch.json +
    # running-apps.sh), idempotent. ~/.local/bin is already on PATH via .zshrc.
    echo "  - Helper: init-vscode"
    mkdir -p "$HOME/.local/bin"
    cp "$DOTFILES_DIR/bin/init-vscode" "$HOME/.local/bin/init-vscode"
    chmod +x "$HOME/.local/bin/init-vscode"

    # WSL-only integrations, skipped on a native Linux box where there's no
    # Windows side.
    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        # ii: reveal a WSL path in Windows Explorer, like PowerShell's
        # Invoke-Item. ~/.local/bin is already on PATH via .zshrc.
        echo "  - WSL helper: ii"
        mkdir -p "$HOME/.local/bin"
        cp "$DOTFILES_DIR/bin/ii" "$HOME/.local/bin/ii"
        chmod +x "$HOME/.local/bin/ii"

        # Sync the Tridactyl config to the Windows user profile so Firefox
        # (running on Windows) picks up the nvim editor integration.
        echo "  - Tridactyl config (Windows side, via WSL)"
        win_home="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || true)"
        if [[ -n "$win_home" && -d "$win_home" ]]; then
            mkdir -p "$win_home/.config/tridactyl"
            cp "$DOTFILES_DIR/config/tridactyl/tridactylrc" "$win_home/.config/tridactyl/"
            cp "$DOTFILES_DIR/config/tridactyl/wsl-integration.js" "$win_home/.config/tridactyl/"
        else
            echo "    (could not resolve Windows home; skipped)"
        fi
    fi

    echo "Dotfiles copied!"
}

copy_dotfiles
