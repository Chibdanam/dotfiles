#!/bin/bash
set -euo pipefail
# Install system dependencies via apt

install_apt() {
    echo "Installing system dependencies..."
    
    sudo apt update
    
    sudo apt install -y \
        build-essential \
        curl \
        wget \
        unzip \
        git \
        mosh \
        ripgrep \
        fd-find \
        fzf \
        jq \
        bat \
        eza \
        python3 \
        python3-pip

    # Debian/Ubuntu ship these as batcat and fdfind (name clashes in the
    # archive). Links rather than aliases so scripts and fzf see them too.
    mkdir -p "$HOME/.local/bin"
    ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
    ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

    echo "System dependencies installed!"
}

install_apt
