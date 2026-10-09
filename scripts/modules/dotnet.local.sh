#!/bin/bash
set -euo pipefail
# Work machine .NET tools, run by install.sh right after the dotnet module

install_local_dotnet() {
    # Authenticates dotnet restore against the Azure Artifacts feeds; cased as
    # the live mise config has it
    echo "Installing the Azure Artifacts credential provider..."
    mise use --global dotnet:Microsoft.Artifacts.CredentialProvider.NuGet.Tool@latest
}

install_local_dotnet
