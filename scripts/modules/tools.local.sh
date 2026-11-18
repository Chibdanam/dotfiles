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

    # Azure CLI with the azure-devops extension: `az boards` and `az repos`,
    # which the gitflow skill drives. Microsoft's script adds their apt
    # repository; `az login` stays a manual step.
    if ! command -v az &> /dev/null; then
        echo "Installing the Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        echo "Azure CLI already installed"
    fi
    if ! az extension show --name azure-devops &> /dev/null; then
        echo "Installing the azure-devops extension..."
        az extension add --name azure-devops --only-show-errors
    fi
    # Without these defaults every `az boards` and `az repos` command wants
    # --organization and --project. One already set is kept.
    local defaults
    defaults=$(az devops configure --list 2> /dev/null || true)
    if ! grep -q '^organization' <<< "$defaults"; then
        az devops configure --defaults organization=https://dev.azure.com/conferosas
    fi
    if ! grep -q '^project' <<< "$defaults"; then
        az devops configure --defaults project=peren
    fi
    if ! az account show &> /dev/null; then
        add_notice "Azure is not logged in: run 'az login --use-device-code'"
    fi

    echo "Work machine tools installed!"
}

install_local_tools
