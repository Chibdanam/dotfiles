#!/bin/bash
set -euo pipefail
# Install Docker Engine with its compose and buildx plugins, from Docker's apt
# repository, and let the user run it without sudo.

install_docker() {
    # On WSL, docker comes from Docker Desktop on the Windows side, and an
    # engine installed here would compete with it. Its `docker` command is only
    # there while Docker Desktop runs, so the test is the platform.
    if grep -qiE '(microsoft|wsl)' /proc/version 2> /dev/null; then
        echo "WSL: Docker is left to Docker Desktop"
        return
    fi

    if command -v docker &> /dev/null; then
        echo "Docker already installed"
    else
        echo "Installing Docker Engine..."
        local distro codename
        distro=$(. /etc/os-release && echo "$ID")
        codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL "https://download.docker.com/linux/$distro/gpg" -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$distro $codename stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    # gpasswd, not usermod: usermod only knows the accounts of /etc/passwd, and
    # a directory account is not there.
    local user
    user=$(id -un)
    if ! getent group docker | cut -d: -f4 | tr ',' '\n' | grep -qxF "$user"; then
        sudo gpasswd -a "$user" docker
        add_notice "Log out and back in: docker runs without sudo once the session is in the docker group. A herdr server already running keeps its old groups until it restarts."
    fi

    echo "Docker installed!"
}

install_docker
