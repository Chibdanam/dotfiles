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
    echo "Installing .NET SDK..."
    mise use --global dotnet@latest

    # Install roslyn-language-server; all its nuget.org builds are prerelease,
    # which needs a current mise (older releases queried NuGet with
    # prerelease=false and failed — hence the update in mise.sh).
    echo "Installing roslyn-language-server..."
    mise use --global dotnet:roslyn-language-server@latest

    # Install csharpier
    echo "Installing csharpier..."
    mise use --global dotnet:csharpier@latest

    # Install dotnet-ef
    echo "Installing dotnet-ef..."
    mise use --global dotnet:dotnet-ef@latest

    # Install ilspycmd
    echo "Installing ilspycmd..."
    mise use --global dotnet:ilspycmd@latest

    # Install sqlpackage
    echo "Installing microsoft.sqlpackage..."
    mise use --global dotnet:microsoft.sqlpackage@latest

    # Install powershell
    echo "Installing powershell..."
    mise use --global dotnet:powershell@latest

    add_notice "Open a new shell so mise puts the .NET global tools on PATH (Neovim's roslyn_ls and conform.nvim resolve them from there)."

    echo ".NET SDK and global tools installed!"
}

install_dotnet
