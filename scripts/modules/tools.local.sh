#!/bin/bash
set -euo pipefail
# Work machine CLIs, run by install.sh right after the tools module

install_local_tools() {
    echo "Installing work machine tools..."

    # bruno and postman-cli: API collection runners
    local -a mise_tools=(
        python
        npm:@usebruno/cli
        npm:postman-cli
    )
    local tool
    for tool in "${mise_tools[@]}"; do
        echo "Installing $tool via mise..."
        mise use --global "$tool@latest"
    done

    echo "Work machine tools installed!"
}

install_local_tools
