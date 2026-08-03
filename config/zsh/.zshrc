# -U drops duplicates: this file re-prepends on every shell, nested ones included
typeset -U path PATH
path=("$HOME/.dotnet/tools" "$HOME/.cargo/bin" "$HOME/.local/bin" /snap/bin $path)
export PATH

# Zinit. Keyed on zinit.zsh, not the directory: an interrupted clone leaves a
# .git-only tree that a -d test accepts, silently disabling every plugin below.
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    [[ -e "$ZINIT_HOME" ]] && rm -rf -- "$ZINIT_HOME"
    mkdir -p -- "${ZINIT_HOME:h}"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"

    zinit light zsh-users/zsh-syntax-highlighting
    zinit light zsh-users/zsh-completions
    zinit light zsh-users/zsh-autosuggestions
    zinit light Aloxaf/fzf-tab
else
    print -u2 "zinit: unavailable at $ZINIT_HOME - syntax highlighting, autosuggestions and fzf-tab are off"
fi

autoload -Uz compinit && compinit

if command -v zinit > /dev/null 2>&1; then
    zinit cdreplay -q
fi

# Source configs (ZDOTDIR is set by ~/.zshenv to $XDG_CONFIG_HOME/zsh)
for config in "${ZDOTDIR:-$HOME/.config/zsh}"/*.zsh(N); do
    source "$config"
done
