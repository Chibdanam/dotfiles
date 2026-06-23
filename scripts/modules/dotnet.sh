#!/bin/bash
set -euo pipefail
# Install .NET SDK plus the Roslyn Language Server and csharpier as global
# dotnet tools. The `roslyn-language-server` NuGet package (publisher: Microsoft
# + RoslynTeam) wraps Microsoft.CodeAnalysis.LanguageServer and is published on
# the public nuget.org feed under that alias — unlike the upstream MS package,
# which is only on an Azure DevOps internal feed. nvim-lspconfig's roslyn_ls
# auto-discovers the binary on PATH. csharpier is the formatter wired through
# conform.nvim.

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

    # `dotnet tool install -g` drops binaries here; make them findable for
    # the rest of this install session so the idempotency checks below work.
    export PATH="$HOME/.dotnet/tools:$PATH"

    # roslyn-language-server — Roslyn LS published to nuget.org. --prerelease is
    # required: every published version carries a prerelease suffix (e.g.
    # 5.8.0-1.26266.2). Without that flag, `dotnet tool install` rejects them.
    if ! command -v roslyn-language-server &> /dev/null; then
        echo "Installing roslyn-language-server..."
        mise exec -- dotnet tool install --global roslyn-language-server --prerelease
    else
        echo "roslyn-language-server already installed; updating..."
        mise exec -- dotnet tool update --global roslyn-language-server --prerelease
    fi

    # csharpier — formatter used by conform.nvim for .cs files
    if ! command -v csharpier &> /dev/null; then
        echo "Installing csharpier..."
        mise exec -- dotnet tool install --global csharpier
    else
        echo "csharpier already installed; updating..."
        mise exec -- dotnet tool update --global csharpier
    fi

    # Surface a notice if the user's current PATH doesn't include the tools
    # directory yet (config/zsh/.zshrc adds it, but the running shell that
    # invoked install.sh may predate that change).
    case ":${PATH-}:" in
        *":$HOME/.dotnet/tools:"*) ;;
        *)
            add_notice "Open a new shell (or 'source ~/.config/zsh/.zshrc') so \$HOME/.dotnet/tools is on PATH — needed for Neovim's roslyn_ls and csharpier."
            ;;
    esac

    echo ".NET SDK, roslyn-language-server, and csharpier installed!"
}

install_dotnet
