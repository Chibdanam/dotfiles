#!/bin/bash
set -euo pipefail
# SSH keys and client config. Every step looks at what is there first: a host
# already in ~/.ssh/config and a key already on disk are left alone.

SSH_DIR="$HOME/.ssh"

# ssh_key <file> <type> <purpose> [bits]: create the key unless it exists.
# Unattended (an agent VM), it has no passphrase, so that the machine keeps
# working after a reboot with nobody to type one; otherwise ssh-keygen asks.
ssh_key() {
    local file="$1" type="$2" purpose="$3" bits="${4:-}"
    if [[ -f "$file" ]]; then
        echo "  - $(basename "$file"): already there"
        return
    fi
    local -a args=(-q -t "$type" -C "$(hostname) $purpose" -f "$file")
    [[ -n "$bits" ]] && args+=(-b "$bits")
    [[ "${DOTFILES_UNATTENDED:-}" == 1 ]] && args+=(-N "")
    ssh-keygen "${args[@]}"
    echo "  - $(basename "$file"): generated"
}

# ssh_host <host> <key file> <type> [bits]: a Host block for <host> with its
# own key, unless ~/.ssh/config already names that host.
ssh_host() {
    local host="$1" key="$2" type="$3" bits="${4:-}"
    local config="$SSH_DIR/config"
    if grep -qsE "^[[:space:]]*Host[[:space:]]+(.*[[:space:]])?${host//./\\.}([[:space:]]|\$)" "$config"; then
        echo "  - $host: already in ~/.ssh/config"
        return
    fi
    ssh_key "$key" "$type" "$host" "$bits"
    # accept-new: the first connection records the host key, a changed one
    # is still refused. No prompt for a clone that runs unattended.
    {
        [[ -s "$config" ]] && echo ""
        echo "Host $host"
        echo "    HostName $host"
        echo "    User git"
        echo "    IdentityFile ${key/#$HOME/\~}"
        echo "    IdentitiesOnly yes"
        echo "    StrictHostKeyChecking accept-new"
    } >> "$config"
    chmod 600 "$config"
    echo "  - $host: added to ~/.ssh/config"
}

# ssh_registered <host> <accepted pattern> <where to paste the key> [command]:
# a notice with the public key as long as <host> does not know it. These hosts
# give no shell and exit non-zero either way, so the answer is read in what
# they say, to [command] when a bare connection does not tell. -n: a host that
# runs [command] waits for the end of standard input, which never comes from a
# terminal.
ssh_registered() {
    local host="$1" accepted="$2" where="$3" command="${4:-}"
    local key
    key=$(ssh -G "$host" 2> /dev/null | awk '$1 == "identityfile" { print $2; exit }')
    key="${key/#\~/$HOME}"
    if [[ ! -f "$key.pub" ]]; then
        return
    fi
    local answer
    answer=$(ssh -n -T -o BatchMode=yes -o ConnectTimeout=10 "git@$host" ${command:+"$command"} 2>&1 || true)
    if grep -qE "$accepted" <<< "$answer"; then
        echo "  - $host: key accepted"
        return
    fi
    echo "  - $host: key not registered yet"
    add_notice "Register this key in $where: $(cat "$key.pub")"
}

setup_ssh() {
    echo "Setting up SSH..."

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    ssh_host github.com "$SSH_DIR/id_ed25519" ed25519
    ssh_registered github.com "successfully authenticated" \
        "GitHub (Settings, SSH and GPG keys, authentication key)"

    # The key git signs commits with (scripts/modules/git.sh wires it).
    local signing="$SSH_DIR/id_ed25519_signing"
    if [[ ! -f "$signing" ]]; then
        ssh_key "$signing" ed25519 signing
        add_notice "Register this key in GitHub (Settings, SSH and GPG keys, signing key): $(cat "$signing.pub")"
    else
        echo "  - $(basename "$signing"): already there"
    fi
}

setup_ssh
