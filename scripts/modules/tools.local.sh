#!/bin/bash
set -euo pipefail
# Work machine CLIs, run by install.sh right after the tools module

install_local_tools() {
    echo "Installing work machine tools..."

    echo "Installing python..."
    mise use --global python@latest

    # postman-cli: runs the Postman API collections
    echo "Installing postman-cli..."
    mise use --global npm:postman-cli@latest

    # opencode v1, which config/opencode/opencode.jsonc targets, into
    # ~/.opencode/bin, already on PATH via .zshrc. --no-modify-path: the
    # installer would otherwise append to the versioned .zshrc. Self-updates
    # with `opencode upgrade`, run by update-all.
    if [[ ! -x "$HOME/.opencode/bin/opencode" ]]; then
        echo "Installing opencode..."
        curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
    else
        echo "opencode already installed"
    fi

    echo "Work machine tools installed!"
}

install_local_tools
