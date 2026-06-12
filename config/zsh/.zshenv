# Tell zsh to read its config from XDG_CONFIG_HOME/zsh instead of $HOME.
# This file lives at ~/.zshenv (sourced before .zshrc on every zsh startup);
# everything else (.zshrc, *.zsh) lives under $ZDOTDIR.
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# Machine-local secrets (tokens / API keys), created per machine and git-ignored.
# See config/zsh/secrets.zsh.example.
[[ -r "$ZDOTDIR/.secrets.zsh" ]] && source "$ZDOTDIR/.secrets.zsh"

