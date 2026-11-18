#!/bin/bash
set -euo pipefail
# Work machine .NET, run by install.sh right after the dotnet module

install_local_dotnet() {
    # The work projects target .NET 8 and 10, not the latest the dotnet module
    # installs. mise keeps every SDK in one root: dotnet picks the one a
    # project asks for, and the global config stays on the latest.
    echo "Installing the .NET SDKs of the work projects..."
    mise install dotnet@10 dotnet@8

    # Authenticates dotnet restore against the Azure Artifacts feeds; cased as
    # the live mise config has it
    echo "Installing the Azure Artifacts credential provider..."
    mise use --global dotnet:Microsoft.Artifacts.CredentialProvider.NuGet.Tool@latest
}

install_local_dotnet
