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
    
    echo "System dependencies installed!"
}

install_apt
