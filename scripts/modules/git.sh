#!/bin/bash
set -euo pipefail
# Setup git configuration

_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$_MODULE_DIR")")"

setup_git() {
    echo "Setting up git configuration..."

    local current_git_name=""
    local current_git_email=""
    local keep_current_identity=""
    local git_name=""
    local git_email=""

    current_git_name="$(git config --global --get user.name || true)"
    current_git_email="$(git config --global --get user.email || true)"

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

    # Prompt for user identity
    if [[ -n "$current_git_name" && -n "$current_git_email" ]]; then
        echo "Current git identity:"
        echo "  Name:  $current_git_name"
        echo "  Email: $current_git_email"
        read -rp "Keep git identity '$current_git_name <$current_git_email>'? [Y/n] " keep_current_identity

        if [[ ! "$keep_current_identity" =~ ^([Nn]|no|NO)$ ]]; then
            git_name="$current_git_name"
            git_email="$current_git_email"
        fi
    fi

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        read -rp "Git user name: " git_name
        read -rp "Git user email: " git_email
    fi

    # --file, not --global: ~/.gitconfig is overwritten by every install
    git config --file "$git_local" user.name "$git_name"
    git config --file "$git_local" user.email "$git_email"

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
    fi

    # Global gitignore (core.excludesfile). Named without the dot in the repo so
    # it doesn't act as an ignore file for config/git/ itself.
    cp "$DOTFILES_DIR/config/git/gitignore" "$HOME/.gitignore"

    echo "Git configuration complete!"
    # --includes: with an explicit scope, git config skips include.path by
    # default, which would print these as empty.
    echo "  Name:  $(git config --global --includes user.name)"
    echo "  Email: $(git config --global --includes user.email)"
}

setup_git
