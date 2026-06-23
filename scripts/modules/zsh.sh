#!/bin/bash
set -euo pipefail
# Install zsh and oh-my-posh

set_default_shell_to_zsh() {
    local zsh_path
    zsh_path="$(which zsh)"

    echo "Setting zsh as default shell..."
    if chsh -s "$zsh_path"; then
        return 0
    fi

    echo ""
    echo "chsh failed (this commonly happens when your user is provided by a directory service"
    echo "like Entra ID / SSSD / LDAP and isn't present in /etc/passwd)."
    echo ""

    if [[ ! -t 0 ]]; then
        echo "Non-interactive shell, skipping fallback. Change your default shell manually later."
        return 0
    fi

    read -p "Fallback: add 'exec zsh' to ~/.bashrc so bash launches zsh on login? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping default shell change."
        return 0
    fi

    local marker="# dotfiles: launch zsh for interactive shells"
    if [[ -f "$HOME/.bashrc" ]] && grep -qF "$marker" "$HOME/.bashrc"; then
        echo "~/.bashrc already contains the zsh launcher"
        return 0
    fi

    cat >> "$HOME/.bashrc" <<EOF

$marker
if [ -t 1 ] && [ -z "\${ZSH_VERSION:-}" ] && command -v zsh >/dev/null 2>&1; then
    exec zsh
fi
EOF
    echo "Added zsh launcher to ~/.bashrc"
}

install_zsh() {
    echo "Installing zsh..."
    
    # Install zsh if not present
    if ! command -v zsh &> /dev/null; then
        sudo apt install -y zsh
    else
        echo "zsh already installed"
    fi
    
    # Set zsh as default shell
    if [[ "$SHELL" != *"zsh"* ]]; then
        set_default_shell_to_zsh
    else
        echo "zsh is already the default shell"
    fi
    
    echo "Installing oh-my-posh..."
    
    # Install oh-my-posh
    if ! command -v oh-my-posh &> /dev/null; then
        curl -s https://ohmyposh.dev/install.sh | bash -s
    else
        echo "oh-my-posh already installed"
    fi
    
    echo "Zsh and oh-my-posh installed!"
}

install_zsh
