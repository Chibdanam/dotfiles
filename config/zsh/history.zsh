HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
# Guarded: under a bare TERM these are empty and bindkey errors out.
if [[ -n ${terminfo[kcuu1]} ]]; then
    bindkey "${terminfo[kcuu1]}" history-beginning-search-backward-end
fi
if [[ -n ${terminfo[kcud1]} ]]; then
    bindkey "${terminfo[kcud1]}" history-beginning-search-forward-end
fi
