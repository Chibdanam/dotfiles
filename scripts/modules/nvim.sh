#!/bin/bash
set -euo pipefail
# Install Neovim (latest stable) from GitHub releases

install_nvim() {
    echo "Installing Neovim from GitHub releases..."

    # Remove apt-installed neovim to avoid PATH conflicts.
    # -s not -l: dpkg -l exits 0 even for never-installed packages.
    if dpkg -s neovim &>/dev/null; then
        echo "Removing apt-installed neovim..."
        sudo apt remove -y neovim
    fi

    # Skip the ~30 MB tarball download when the installed nvim is already
    # at the latest release. /releases/latest redirects to
    # /releases/tag/vX.Y.Z, so the final path component IS the tag.
    local latest_version
    latest_version=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
        https://github.com/neovim/neovim/releases/latest | sed 's|.*/||')

    if command -v nvim &> /dev/null; then
        local current_version
        current_version=$(nvim --version | head -1 | awk '{print $2}')
        if [[ "$current_version" == "$latest_version" ]]; then
            echo "Neovim $current_version is already at the latest release ($latest_version); skipping."
            return 0
        fi
        echo "Upgrading Neovim $current_version → $latest_version..."
    fi

    # Remove previous GitHub release install
    if [[ -d /opt/nvim-linux-x86_64 ]]; then
        echo "Removing previous install from /opt/nvim-linux-x86_64..."
        sudo rm -rf /opt/nvim-linux-x86_64
    fi

    local tarball="nvim-linux-x86_64.tar.gz"
    local url="https://github.com/neovim/neovim/releases/latest/download/$tarball"
    local tmp
    tmp="$(mktemp -d)"

    echo "Downloading $url ..."
    curl -fsSL -o "$tmp/$tarball" "$url"

    # Guard against truncated / empty downloads so the next `tar` doesn't
    # produce a confusing error half a step later.
    if [[ ! -s "$tmp/$tarball" ]]; then
        echo "Error: downloaded tarball is empty ($tmp/$tarball)" >&2
        rm -rf "$tmp"
        exit 1
    fi

    echo "Extracting to /opt/nvim-linux-x86_64 ..."
    sudo tar -xzf "$tmp/$tarball" -C /opt
    rm -rf "$tmp"

    # Symlink into PATH
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim

    echo "Neovim $(nvim --version | head -1) installed!"
}

install_nvim
