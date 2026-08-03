#!/bin/bash
set -euo pipefail
# Install the .NET SDK and its global tools through mise, so they show up in
# `mise ls`. The `roslyn-language-server` NuGet package (Microsoft + RoslynTeam)
# wraps Microsoft.CodeAnalysis.LanguageServer and is the only build of it on the
# public nuget.org feed; nvim-lspconfig's roslyn_ls picks the binary off PATH.
# csharpier is the formatter wired through conform.nvim.

install_dotnet() {
    echo "Installing .NET SDK and tooling..."

    # Check if mise is installed
    if ! command -v mise &> /dev/null; then
        echo "Error: mise is not installed. Please run mise.sh first."
        exit 1
    fi

    # Ensure mise is in PATH
    export PATH="$HOME/.local/bin:$PATH"

    # The .NET runtime aborts at startup without ICU
    # (https://aka.ms/dotnet-missing-libicu). Install it here rather than in
    # apt.sh so this module works standalone via `./install.sh dotnet`.
    if ! dpkg -s libicu-dev &> /dev/null; then
        echo "Installing libicu-dev (required by .NET runtime)..."
        sudo apt install -y libicu-dev
    fi

    # Install the .NET SDK via mise's core dotnet backend (uses Microsoft's
    # official install script under the hood, full SDK).
    # Seed the version only once: `use @latest` would overwrite a pin like "10".
    local pinned_dotnet
    pinned_dotnet="$(mise config get tools.dotnet 2>/dev/null || true)"
    if [[ -n "$pinned_dotnet" ]]; then
        echo "Keeping the existing mise pin dotnet@$pinned_dotnet"
        mise install dotnet
    else
        echo "Installing .NET SDK..."
        mise use --global dotnet@latest
    fi

    # NuGet package ids, also what `dotnet tool list` prints in column 1.
    # The backend lists prereleases, which roslyn-language-server needs.
    local -a dotnet_tools=(
        roslyn-language-server
        csharpier
        dotnet-ef
        ilspycmd
        microsoft.sqlpackage
        powershell
    )

    local tool
    for tool in "${dotnet_tools[@]}"; do
        echo "Installing $tool via mise..."
        mise use --global "dotnet:$tool@latest"
    done

    # Drop leftovers from the old `dotnet tool install --global` layout: mise
    # comes first on PATH, so they'd be shadowed and never upgraded.
    for tool in "${dotnet_tools[@]}"; do
        if mise exec -- dotnet tool list --global | awk '{print $1}' | grep -qx "$tool"; then
            echo "Removing the superseded global dotnet tool $tool..."
            mise exec -- dotnet tool uninstall --global "$tool"
        fi
    done

    add_notice "Open a new shell so mise puts the .NET global tools on PATH (Neovim's roslyn_ls and conform.nvim resolve them from there)."

    echo ".NET SDK and global tools installed!"
}

install_dotnet
