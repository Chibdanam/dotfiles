#!/bin/bash
# Dotfiles Bootstrap Script
# Usage: ./install.sh [module|all]
#   e.g. ./install.sh all
#        ./install.sh nvim
#        ./install.sh zsh tmux

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/scripts/modules"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Action items modules can defer until the end of the install run,
# so they don't get lost in the middle of a long output stream.
POST_INSTALL_NOTICES=()

add_notice() {
    POST_INSTALL_NOTICES+=("$1")
}

print_notices() {
    if [[ ${#POST_INSTALL_NOTICES[@]} -eq 0 ]]; then
        return
    fi
    echo ""
    echo -e "${YELLOW}Action items:${NC}"
    for notice in "${POST_INSTALL_NOTICES[@]}"; do
        echo -e "  ${YELLOW}-${NC} $notice"
    done
}

# Available modules
declare -A MODULES=(
    ["apt"]="System dependencies (build-essential, curl, etc.)"
    ["zsh"]="Zsh shell and oh-my-posh"
    ["tmux"]="Tmux terminal multiplexer"
    ["herdr"]="Herdr terminal workspace manager"
    ["nvim"]="Neovim (latest stable from GitHub)"
    ["mise"]="mise runtime manager"
    ["node"]="Node.js LTS, bun, pnpm, npm packages"
    ["rust"]="Rust toolchain via rustup"
    ["dotnet"]=".NET SDK + Roslyn LS + csharpier (via mise)"
    ["tools"]="Additional tools (Claude Code, zoxide, delta, lazygit, gh, macchina)"
    ["claude"]="Claude Code global configuration and skills"
    ["ssh"]="SSH key generation"
    ["git"]="Git configuration"
    ["dotfiles"]="Copy all dotfiles to home directory"
)

# Order for full install
INSTALL_ORDER=(apt ssh zsh tmux herdr nvim mise node rust dotnet tools claude git dotfiles)

show_help() {
    echo "Dotfiles Bootstrap Script"
    echo ""
    echo "Usage: ./install.sh [module...] | all"
    echo ""
    echo "Modules:"
    for module in "${!MODULES[@]}"; do
        printf "  %-12s %s\n" "$module" "${MODULES[$module]}"
    done
    echo ""
    echo "Examples:"
    echo "  ./install.sh all          # Install everything"
    echo "  ./install.sh nvim         # Install only neovim"
    echo "  ./install.sh zsh tmux     # Install zsh and tmux"
    echo ""
    echo "After installation, open a new shell to load the prompt and tools"
}

run_module() {
    local module="$1"
    local script="$MODULES_DIR/$module.sh"
    
    if [[ ! -f "$script" ]]; then
        print_error "Module '$module' not found"
        return 1
    fi
    
    print_header "Installing: ${MODULES[$module]}"
    source "$script"
    print_success "Module '$module' completed"
}

install_all() {
    print_header "Full Installation"
    echo "This will install:"
    for module in "${INSTALL_ORDER[@]}"; do
        echo "  - ${MODULES[$module]}"
    done
    echo ""
    
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    for module in "${INSTALL_ORDER[@]}"; do
        run_module "$module"
    done
    
    print_header "Installation Complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Log out and log back in (for shell change)"
    echo "  2. Open a new terminal"
    echo "  3. Run 'nvim' to install plugins"
    print_notices
    echo ""
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        exit 0
    fi
    
    if [[ "$1" == "all" ]]; then
        install_all
        exit 0
    fi
    
    # Install specific modules
    for module in "$@"; do
        if [[ -z "${MODULES[$module]}" ]]; then
            print_error "Unknown module: $module"
            echo "Run './install.sh --help' for available modules"
            exit 1
        fi
        run_module "$module"
    done

    print_success "Done!"
    print_notices
}

main "$@"
