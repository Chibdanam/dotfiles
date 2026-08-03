# zsh has no default LS_COLORS; bash gets it from ~/.bashrc, which zsh never reads.
if (( $+commands[dircolors] )); then
    eval "$(dircolors -b)"
fi

# Fix bright green background on Windows folders in /mnt. Rebuilt, not
# appended, so nested shells don't stack duplicate ow entries.
typeset -a _ls_colors
_ls_colors=(${(s.:.)LS_COLORS})
_ls_colors=(${_ls_colors:#ow=*})
export LS_COLORS="${(j.:.)_ls_colors}:ow=01;34"
unset _ls_colors

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"   # after LS_COLORS above
zstyle ':completion:*' menu no

# --color=always: fzf pipes the preview, so eza's auto mode would strip colour.
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always $realpath'
