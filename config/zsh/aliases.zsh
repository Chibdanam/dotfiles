# Text Editors & Files
alias v="nvim"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ls='ls --color'
alias bat='batcat'
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
alias vswap="rm -rf ~/.local/state/nvim/swap/"
alias fetch="macchina"

alias cd='z'
alias ls='eza'
alias ll='eza -l'
alias lt='eza --tree --git-ignore --level=2'