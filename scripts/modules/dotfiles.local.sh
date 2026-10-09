#!/bin/bash
set -euo pipefail
# Work machine steps, run by install.sh right after the dotfiles module

_LOCAL_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LOCAL_DOTFILES_DIR="$(dirname "$(dirname "$_LOCAL_MODULE_DIR")")"

copy_local_dotfiles() {
    echo "Copying work machine dotfiles..."

    # opencode writes its own package.json/node_modules here: only the config
    # is ours. It reads the DGX key from ~/.config/dgx/token and refuses to
    # start if that file is missing, so seed an empty one (fill it by hand).
    echo "  - opencode config"
    mkdir -p "$HOME/.config/opencode"
    cp "$_LOCAL_DOTFILES_DIR/config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc"
    if [ ! -e "$HOME/.config/dgx/token" ]; then
        mkdir -p "$HOME/.config/dgx"
        install -m 600 /dev/null "$HOME/.config/dgx/token"
        echo "  - Seeded empty ~/.config/dgx/token (paste the DGX gateway key)"
    fi

    echo "  - Lazygit work layer"
    cp "$_LOCAL_DOTFILES_DIR/config/lazygit/config.local.yml" "$HOME/.config/lazygit/config.local.yml"
}

copy_local_dotfiles
