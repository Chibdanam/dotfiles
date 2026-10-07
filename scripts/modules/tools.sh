#!/bin/bash
set -euo pipefail
# Install additional CLI tools

install_tools() {
    echo "Installing additional tools..."
    
    # Check if mise is installed
    if ! command -v mise &> /dev/null; then
        echo "Error: mise is not installed. Please run mise.sh first."
        exit 1
    fi
    
    # Ensure mise is in PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Install Claude Code
    if ! command -v claude &> /dev/null; then
        echo "Installing Claude Code..."
        curl -fsSL https://claude.ai/install.sh | bash
    else
        echo "Claude Code already installed"
    fi

    # Install rtk (compresses command output for Claude Code). No self-update:
    # through mise, `mise up` keeps it current.
    echo "Installing rtk..."
    mise use --global github:rtk-ai/rtk@latest

    # Install codegraph (code graph MCP server for Claude Code). Self-updates
    # with `codegraph upgrade`, run by update-all.
    if ! command -v codegraph &> /dev/null; then
        echo "Installing codegraph..."
        curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
    else
        echo "codegraph already installed"
    fi

    # Install opencode into ~/.opencode/bin, already on PATH via .zshrc.
    # --no-modify-path: the installer would otherwise append to the versioned
    # .zshrc. Self-updates with `opencode upgrade`, run by update-all.
    if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
        echo "Installing opencode..."
        curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    else
        echo "opencode already installed"
    fi

    # Install zoxide
    echo "Installing zoxide..."
    mise use --global zoxide@latest
    
    # Install delta (git diff tool)
    echo "Installing delta..."
    mise use --global delta@latest
    
    # Install lazygit
    echo "Installing lazygit..."
    mise use --global lazygit@latest

    # Install bottom (system monitor, `btm`)
    echo "Installing bottom..."
    mise use --global bottom@latest

    # Install lazydocker (Docker TUI)
    echo "Installing lazydocker..."
    mise use --global lazydocker@latest

    # Install uv. Comes before any pipx:* tool: mise installs those through uv.
    echo "Installing uv..."
    mise use --global uv@latest

    # Install claude-swap (switch between Claude accounts)
    echo "Installing claude-swap..."
    mise use --global pipx:claude-swap@latest

    # Install macchina (Rust-based system info fetch, aliased to `fetch`).
    # mise's registry doesn't include macchina; build from source via cargo.
    if ! command -v macchina &>/dev/null; then
        if command -v cargo &>/dev/null; then
            echo "Installing macchina (compiles from source, ~1 minute)..."
            cargo install --locked macchina
        else
            echo "Skipping macchina: cargo not found."
            echo "  Install Rust (https://rustup.rs), then re-run './install.sh tools'."
        fi
    else
        echo "macchina already installed"
    fi

    # Install GitHub CLI (used by snacks.dashboard GitHub sections)
    if ! command -v gh &>/dev/null; then
        echo "Installing GitHub CLI..."
        mise use --global gh@latest
    else
        echo "gh already installed"
    fi

    # Install shell-color-scripts (provides `colorscript`, used by snacks.dashboard)
    if ! command -v colorscript &> /dev/null; then
        echo "Installing colorscript..."
        tmpdir="$(mktemp -d)"
        git clone --depth=1 https://gitlab.com/dwt1/shell-color-scripts.git "$tmpdir"
        sudo make -C "$tmpdir" install
        rm -rf "$tmpdir"
    else
        echo "colorscript already installed"
    fi

    echo "Additional tools installed!"
}

install_tools
