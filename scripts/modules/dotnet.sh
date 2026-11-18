#!/bin/bash
set -euo pipefail
# Install the .NET SDK and its global tools through mise, so they show up in
# `mise ls`. The `roslyn-language-server` NuGet package (Microsoft + RoslynTeam)
# wraps Microsoft.CodeAnalysis.LanguageServer and is the only build of it on the
# public nuget.org feed; nvim-lspconfig's roslyn_ls picks the binary off PATH.
# csharpier is the formatter wired through conform.nvim.

# A release can reach NuGet before its per-platform package
# (powershell.linux-x64), and @latest then fails until that package lands:
# fall back on the newest earlier release that installs. The pin this leaves
# in the mise config goes away on the first run where @latest works again.
install_powershell() {
    if mise use --global dotnet:powershell@latest; then
        return
    fi
    local version
    while read -r version <&3; do
        echo "  - powershell@latest does not install, trying $version"
        if mise use --global "dotnet:powershell@$version"; then
            return
        fi
    done 3< <(mise ls-remote dotnet:powershell | grep -E '^[0-9]+(\.[0-9]+)+$' | tac | sed -n '2,4p')
    add_notice "powershell was not installed, neither its latest release nor the three before have a package for this platform: retry later with './install.sh dotnet'"
}

# tool_runtime <command> [args]: a tool built for an earlier .NET than the SDK
# just installed does not start ("You must install or update .NET") and names
# the runtime it wants: install that one next to the latest. mise keeps every
# SDK in one root, so the tool finds it without a change to the global config.
tool_runtime() {
    local answer major
    answer=$(timeout 30 "$@" 2>&1 || true)
    major=$(sed -n "s/.*Framework: 'Microsoft.NETCore.App', version '\([0-9]*\)\..*/\1/p" <<< "$answer" | head -n 1)
    if [[ -z "$major" ]]; then
        return
    fi
    echo "  - $1 needs .NET $major, installing it next to the latest"
    mise install "dotnet@$major"
}

install_dotnet() {
    echo "Installing .NET SDK and tooling..."

    # Tools already there are on PATH through the mise shims: only a first
    # install needs a new shell to see them.
    local first_install=0
    command -v roslyn-language-server &> /dev/null || first_install=1

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

    echo "Installing powershell..."
    install_powershell

    echo "Checking that the tools start..."
    tool_runtime csharpier --version
    tool_runtime dotnet-ef --version
    tool_runtime ilspycmd --version
    tool_runtime sqlpackage /version
    tool_runtime pwsh -v
    tool_runtime roslyn-language-server --version

    if [[ "$first_install" == 1 ]]; then
        add_notice "Open a new terminal: the .NET tools just installed are not on the PATH of the shells already open."
    fi

    echo ".NET SDK and global tools installed!"
}

install_dotnet
