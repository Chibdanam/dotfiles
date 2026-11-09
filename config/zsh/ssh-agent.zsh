# One ssh-agent per boot on a fixed socket, shared by every shell and what it
# starts. git signs through it (gpg.ssh.program = git-ssh-sign).
export SSH_AUTH_SOCK=$HOME/.ssh/agent.sock

ssh-add -l > /dev/null 2>&1
if [[ $? -eq 2 ]]; then
    rm -f -- "$SSH_AUTH_SOCK"
    ssh-agent -a "$SSH_AUTH_SOCK" > /dev/null
fi

# The signing key's passphrase is typed once per boot and never stored.
if [[ -o interactive && -f ~/.ssh/id_ed25519_signing.pub ]] &&
    ! ssh-add -T ~/.ssh/id_ed25519_signing.pub > /dev/null 2>&1; then
    print -P "%F{yellow}git: signing key not loaded, run ssh-add ~/.ssh/id_ed25519_signing%f"
fi
