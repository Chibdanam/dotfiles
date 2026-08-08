#!/bin/bash
set -euo pipefail
# Generate SSH key for GitHub

setup_ssh() {
    echo "Setting up SSH..."

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Any existing keypair counts — key names vary per machine (e.g.
    # id_ed25519_github_wsl), so don't insist on the default id_ed25519.
    local existing
    existing=$(find "$HOME/.ssh" -maxdepth 1 -type f -name '*.pub' 2>/dev/null | sort)

    if [[ -n "$existing" ]]; then
        echo "SSH key(s) already present, skipping generation:"
        local pub
        while IFS= read -r pub; do
            echo "  - $(basename "${pub%.pub}")"
        done <<< "$existing"
        return
    fi

    read -rp "Email for SSH key: " ssh_email
    ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519"

    echo ""
    echo "Your public key (add to GitHub → Settings → SSH keys):"
    echo ""
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
}

setup_ssh
