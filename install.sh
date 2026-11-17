#!/bin/bash
# Dotfiles Bootstrap Script
# Usage: ./install.sh [module|all]
#   e.g. ./install.sh all
#        ./install.sh nvim
#        ./install.sh zsh herdr

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

# Where the modules install their binaries. Each module runs in its own
# subshell, so what one adds to PATH would not reach the next. The mise shims
# are there for the tools mise installs: without them the claude module does
# not see rtk on a fresh machine and skips its hook.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:$PATH"

# Action items modules can defer until the end of the install run,
# so they don't get lost in the middle of a long output stream.
# In a file, not an array: a module's subshell could not append to it.
NOTICES_FILE="$(mktemp)"
trap 'rm -f "$NOTICES_FILE"' EXIT

add_notice() {
    printf '%s\n' "$1" >> "$NOTICES_FILE"
}

print_notices() {
    if [[ ! -s "$NOTICES_FILE" ]]; then
        return
    fi
    echo ""
    echo -e "${YELLOW}Action items:${NC}"
    local notice
    while IFS= read -r notice; do
        echo -e "  ${YELLOW}-${NC} $notice"
    done < "$NOTICES_FILE"
}

# A failed module is reported at the end; the modules after it still run.
FAILED_MODULES=()

print_failures() {
    if [[ ${#FAILED_MODULES[@]} -eq 0 ]]; then
        return
    fi
    echo ""
    print_error "Failed modules: ${FAILED_MODULES[*]}"
    echo "  Fix the cause above, then re-run them: ./install.sh ${FAILED_MODULES[*]}"
}

# Available modules
declare -A MODULES=(
    ["apt"]="System dependencies (build-essential, curl, etc.)"
    ["zsh"]="Zsh shell and oh-my-posh"
    ["herdr"]="Herdr terminal workspace manager"
    ["nvim"]="Neovim (latest stable from GitHub)"
    ["mise"]="mise runtime manager"
    ["node"]="Node.js LTS, bun, pnpm, npm packages"
    ["rust"]="Rust toolchain via rustup"
    ["dotnet"]=".NET SDK + Roslyn LS + csharpier (via mise)"
    ["tools"]="Additional tools (Claude Code, rtk, codegraph, opencode, zoxide, delta, lazygit, bruno, gh, macchina)"
    ["claude"]="Claude Code global configuration and skills"
    ["ssh"]="SSH key generation"
    ["git"]="Git configuration"
    ["dotfiles"]="Copy all dotfiles to home directory"
)

# Order for full install
INSTALL_ORDER=(apt ssh zsh herdr nvim mise node rust dotnet tools claude git dotfiles)

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
    echo "  ./install.sh zsh herdr    # Install zsh and herdr"
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
    # In a subshell: a module sets -e, and its failure must end the module,
    # not the install. Run as a plain command, not as a condition, where
    # bash would ignore -e inside it.
    local status=0
    set +e
    (
        set -e
        source "$script"
        # A branch layered on this one adds steps to a module without editing it
        if [[ -f "$MODULES_DIR/$module.local.sh" ]]; then
            source "$MODULES_DIR/$module.local.sh"
        fi
    )
    status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        print_error "Module '$module' failed (exit $status), moving on to the next one"
        FAILED_MODULES+=("$module")
        return 0
    fi
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
    
    if [[ ${#FAILED_MODULES[@]} -eq 0 ]]; then
        print_header "Installation Complete!"
    else
        print_header "Installation finished with failures"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Log out and log back in (for shell change)"
    echo "  2. Open a new terminal"
    echo "  3. Run 'nvim' to install plugins"
    print_notices
    print_failures
    echo ""
    [[ ${#FAILED_MODULES[@]} -eq 0 ]]
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
        exit $?
    fi
    
    # Install specific modules
    for module in "$@"; do
        # :- because set -u aborts on a missing key before this message prints
        if [[ -z "${MODULES[$module]:-}" ]]; then
            print_error "Unknown module: $module"
            echo "Run './install.sh --help' for available modules"
            exit 1
        fi
        run_module "$module"
    done

    if [[ ${#FAILED_MODULES[@]} -eq 0 ]]; then
        print_success "Done!"
    fi
    print_notices
    print_failures
    [[ ${#FAILED_MODULES[@]} -eq 0 ]]
}

main "$@"
