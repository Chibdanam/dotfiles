#!/bin/bash
set -euo pipefail
# Work machine SSH, run by install.sh right after the ssh module

setup_local_ssh() {
    # Azure DevOps takes RSA keys only: the ed25519 key of GitHub does not
    # serve there.
    ssh_host ssh.dev.azure.com "$SSH_DIR/id_rsa_azdo" rsa 4096

    # Azure DevOps answers a bare connection the same with any key, and only
    # checks the key against an organization. Asking that organization for a
    # project that does not exist tells: "TF200016: project does not exist"
    # with a known key, "Public key authentication failed" otherwise.
    ssh_registered ssh.dev.azure.com "remote: TF[0-9]+" \
        "Azure DevOps (User settings, SSH public keys)" \
        "git-upload-pack 'v3/conferosas/_/_'"
}

setup_local_ssh
