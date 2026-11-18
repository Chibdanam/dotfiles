#!/bin/bash
set -euo pipefail
# Setup git configuration

_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$_MODULE_DIR")")"

# The identity already in place is kept without a question: to change it,
# edit ~/.gitconfig.local. A machine that has none takes DOTFILES_GIT_NAME
# and DOTFILES_GIT_EMAIL when they are set, or asks at a terminal.
setup_git_identity() {
    local git_local="$1" name="$2" email="$3"

    if [[ -n "$name" && -n "$email" ]]; then
        echo "  - Kept identity: $name <$email>"
    else
        name="${DOTFILES_GIT_NAME:-}"
        email="${DOTFILES_GIT_EMAIL:-}"
        if [[ -z "$name" || -z "$email" ]]; then
            if [[ "${DOTFILES_UNATTENDED:-}" == 1 || ! -t 0 ]]; then
                add_notice "git has no identity: set user.name and user.email in ~/.gitconfig.local"
                return
            fi
            read -rp "Git user name: " name
            read -rp "Git user email: " email
        fi
    fi

    # --file, not --global: ~/.gitconfig is overwritten by every install
    git config --file "$git_local" user.name "$name"
    git config --file "$git_local" user.email "$email"
}

# Commits signed with ~/.ssh/id_ed25519_signing (created by the ssh module),
# through git-ssh-sign. A machine that already names a signing key is left
# alone, whatever that key is.
setup_git_signing() {
    local git_local="$1"
    local key="$HOME/.ssh/id_ed25519_signing.pub"
    local signers="$HOME/.ssh/allowed_signers"

    if [[ -n "$(git config --file "$git_local" user.signingkey || true)" ]]; then
        echo "  - Kept signing key: $(git config --file "$git_local" user.signingkey)"
        return
    fi
    if [[ ! -f "$key" ]]; then
        add_notice "Commits are not signed: no $key (run ./install.sh ssh git)"
        return
    fi
    local email
    email="$(git config --file "$git_local" user.email || true)"
    if [[ -z "$email" ]]; then
        return
    fi

    # What `git verify-commit` trusts: this identity, with this key.
    local line
    line="$email namespaces=\"git\" $(cut -d' ' -f1,2 "$key")"
    if ! grep -qsxF "$line" "$signers"; then
        echo "$line" >> "$signers"
    fi

    git config --file "$git_local" gpg.format ssh
    git config --file "$git_local" user.signingkey "$key"
    git config --file "$git_local" gpg.ssh.allowedSignersFile "$signers"
    git config --file "$git_local" gpg.ssh.program "$HOME/.local/bin/git-ssh-sign"
    git config --file "$git_local" commit.gpgsign true
    git config --file "$git_local" tag.gpgsign true
    # From when the gitflow pre-push hook requires a signature: now, not the
    # commits made before this machine could sign.
    if [[ -z "$(git config --file "$git_local" gf.signedSince || true)" ]]; then
        git config --file "$git_local" gf.signedSince "$(date -Iseconds)"
    fi
    echo "  - Commits and tags signed with $key"
}

setup_git() {
    echo "Setting up git configuration..."

    local current_git_name=""
    local current_git_email=""

    current_git_name="$(git config --global --includes --get user.name || true)"
    current_git_email="$(git config --global --includes --get user.email || true)"

    # Copy gitconfig
    cp "$DOTFILES_DIR/config/git/.gitconfig" "$HOME/.gitconfig"

    # Machine-local identity and credential helpers: seeded once, then left alone.
    local git_local="$HOME/.gitconfig.local"
    if [ ! -e "$git_local" ]; then
        cp "$DOTFILES_DIR/config/git/gitconfig.local.example" "$git_local"
        echo "  - Seeded $git_local"
    else
        echo "  - Kept existing $git_local"
    fi

    setup_git_identity "$git_local" "$current_git_name" "$current_git_email"
    setup_git_signing "$git_local"

    # With gh from mise, not `gh auth setup-git`: it bakes in the versioned
    # install path, which the next `mise up` deletes. The mise shim always
    # resolves the current gh. The empty entry resets helpers inherited from
    # other config files.
    local gh_shim="$HOME/.local/share/mise/shims/gh"
    if [[ -x "$gh_shim" ]] && "$gh_shim" auth status &> /dev/null; then
        git config --file "$git_local" --unset-all credential.https://github.com.helper || true
        git config --file "$git_local" --add credential.https://github.com.helper ""
        git config --file "$git_local" --add credential.https://github.com.helper "!$gh_shim auth git-credential"
        git config --file "$git_local" --unset-all credential.https://gist.github.com.helper || true
        git config --file "$git_local" --add credential.https://gist.github.com.helper ""
        git config --file "$git_local" --add credential.https://gist.github.com.helper "!$gh_shim auth git-credential"
        echo "  - Pointed the gh credential helpers in $git_local at the mise shim"
    # gh's helper path embeds the gh version, so refresh it here rather than
    # version it. GIT_CONFIG_GLOBAL sends gh's --global writes to the local file.
    elif command -v gh &> /dev/null && gh auth status &> /dev/null; then
        GIT_CONFIG_GLOBAL="$git_local" gh auth setup-git
        echo "  - Refreshed gh credential helpers in $git_local"
    else
        add_notice "GitHub is not logged in: run 'gh auth login', then './install.sh git'"
    fi

    # Global gitignore (core.excludesfile). Named without the dot in the repo so
    # it doesn't act as an ignore file for config/git/ itself.
    cp "$DOTFILES_DIR/config/git/gitignore" "$HOME/.gitignore"

    echo "Git configuration complete!"
    # --includes: with an explicit scope, git config skips include.path by
    # default, which would print these as empty.
    echo "  Name:  $(git config --global --includes user.name || true)"
    echo "  Email: $(git config --global --includes user.email || true)"
}

setup_git
