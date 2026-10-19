#!/bin/bash
set -euo pipefail
# Personal machine CLIs, run by install.sh right after the tools module

install_local_tools() {
    echo "Installing personal machine tools..."

    # opencode v2 into ~/.opencode/bin, already on PATH via .zshrc.
    # --no-modify-path: the installer would otherwise append to the versioned
    # .zshrc. Self-updates with `opencode upgrade`, run by update-all.
    if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
        echo "Installing opencode v2..."
        curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
    else
        echo "opencode already installed"
    fi

    echo "Personal machine tools installed!"
}

install_local_tools
