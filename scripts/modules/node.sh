#!/bin/bash
set -euo pipefail
# Install Node.js LTS, bun, pnpm, and global npm packages via mise

install_node() {
    echo "Installing Node.js and package managers..."
    
    # Check if mise is installed
    if ! command -v mise &> /dev/null; then
        echo "Error: mise is not installed. Please run mise.sh first."
        exit 1
    fi
    
    # Ensure mise is in PATH
    export PATH="$HOME/.local/bin:$PATH"
    
    # Install Node.js LTS
    echo "Installing Node.js LTS..."
    mise use --global node@lts
    
    # Install bun
    echo "Installing bun..."
    mise use --global bun@latest
    
    # Install pnpm via the npm backend; mise's default aqua backend for
    # pnpm currently looks for an asset name pnpm no longer publishes.
    echo "Installing pnpm..."
    mise use --global npm:pnpm@latest
    
    # tree-sitter CLI is required by nvim-treesitter v1 (main branch)
    # to build parsers from the grammars declared in lua/plugins/treesitter.lua.
    if ! command -v tree-sitter &> /dev/null; then
        echo "Installing tree-sitter-cli..."
        mise exec -- npm install -g tree-sitter-cli
    else
        echo "tree-sitter-cli already installed"
    fi

    echo "Node.js, bun, pnpm, and packages installed!"
}

install_node
