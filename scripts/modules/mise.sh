#!/bin/bash
set -euo pipefail
# Install mise - polyglot runtime manager

install_mise() {
    echo "Installing mise..."
    
    if ! command -v mise &> /dev/null; then
        curl https://mise.run | sh
    else
        # An outdated mise breaks the dotnet backend for prerelease-only
        # NuGet tools (roslyn-language-server): old releases queried the
        # search API with prerelease=false, so the tool was "not found".
        echo "mise already installed, updating..."
        mise self-update -y || echo "mise self-update failed, continuing with the current version"
    fi
    
    # Add mise to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"
    
    echo "mise installed!"
}

install_mise
