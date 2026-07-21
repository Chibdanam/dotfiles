# Project directories the sessionizer offers: every immediate subdirectory of
# ~/dev plus the extra monorepo roots listed in fuzzy-dir.local.txt. Dot-folders
# and git-ignored paths (bin/, obj/, node_modules/, ...) are pruned. Prints one
# ~/dev-relative path per line. See config/zsh/fuzzy-dir.example.txt for the file.
dev-project-dirs() {
    local roots_file="${ZDOTDIR:-$HOME/.config/zsh}/fuzzy-dir.local.txt"
    local -a roots=("$HOME/dev")

    # Extra roots, one path per line; '#' comments and blank lines are ignored.
    local line
    [[ -r $roots_file ]] && for line in "${(@f)$(<$roots_file)}"; do
        line=${line%%\#*}; line=${line//[[:space:]]/}
        [[ -z $line ]] && continue
        line=${line/#\~/$HOME}
        [[ $line = /* ]] || line="$HOME/$line"
        roots+=("${line%/}")
    done

    local root; local -a dirs ignored; local -aU out
    for root in $roots; do
        dirs=("$root"/*(N/))                       # immediate subdirs, no dot-folders
        if git -C "$root" rev-parse --is-inside-work-tree &>/dev/null; then
            ignored=("${(@f)$(print -rl -- $dirs | git -C "$root" check-ignore --stdin 2>/dev/null)}")
            dirs=(${dirs:|ignored})                # drop anything git ignores
        fi
        out+=("${(@)dirs#$HOME/dev/}")             # relative to ~/dev
    done
    print -rl -- $out
}

# herdr sessionizer (preferred): pick a project with fzf, then switch to (or
# create) its herdr space with a Claude / run / vim tab layout.
f() {
    local dir
    dir=$(dev-project-dirs | fzf \
        --preview "eza --tree --level=1 --color=always $HOME/dev/{}" \
        --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up')
    [[ -z $dir ]] && return

    local project_path="$HOME/dev/$dir"
    local label=${${dir:t}//[.:]/_}                # folder basename

    # Make sure the herdr server is up so the socket API works.
    if ! herdr workspace list &>/dev/null; then
        herdr server &>/dev/null &!
        local i
        for i in {1..50}; do
            herdr workspace list &>/dev/null && break
            sleep 0.1
        done
    fi

    # Reuse the space if it already exists, otherwise build the 3-tab layout.
    local ws
    ws=$(herdr workspace list 2>/dev/null \
        | jq -r --arg n "$label" '.result.workspaces[]? | select(.label==$n) | .workspace_id' \
        | head -n1)

    if [[ -z $ws ]]; then
        local created tab1
        created=$(herdr workspace create --cwd "$project_path" --label "$label" --focus 2>/dev/null)
        ws=$(print -r -- "$created" | jq -r '.result.workspace.workspace_id')
        tab1=$(print -r -- "$created" | jq -r '.result.tab.tab_id')
        herdr tab rename "$tab1" Claude &>/dev/null
        herdr tab create --workspace "$ws" --cwd "$project_path" --label run --no-focus &>/dev/null
        herdr tab create --workspace "$ws" --cwd "$project_path" --label vim --no-focus &>/dev/null
        herdr tab focus "$tab1" &>/dev/null
    else
        herdr workspace focus "$ws" &>/dev/null
    fi

    # Attach a client only when we're not already inside herdr.
    [[ -z $HERDR_ENV ]] && herdr
}

# Tmux sessionizer (fallback): kept alongside f() so tmux still works where
# herdr isn't the driver. Shares its logic with the `prefix + j` tmux keybind.
tf() {
    "$HOME/.config/tmux/sessionizer.sh"
}

# Fuzzy file finder - open selected file in nvim
ff() {
    local file
    file=$(find "$HOME/dev" "$HOME/.config" -type d \( \
        -path "*/node_modules" -o \
        -path "*/.git" -o \
        -path "*/.cache" -o \
        -path "*/.vscode" -o \
        -path "*/.npm" -o \
        -path "*/dist" -o \
        -path "*/.next" -o \
        -path "*/.expo" -o \
        -path "*/db" -o \
        -path "*/build" -o \
        -path "*/__pycache__" -o \
        -path "*/.idea" -o \
        -path "*/.env" -o \
        -path "*/.vs" -o \
        -path "*/vendor" -o \
        -path "*/coverage" -o \
        -path "*/.terraform" -o \
        -path "*/.bundle" -o \
        -path "*/tmp" -o \
        -path "*/logs" -o \
        -path "*/.sass-cache" \
    \) -prune -o -type f -print 2>/dev/null | \
    fzf --preview 'batcat --color=always --style=numbers --line-range=:500 {}' \
        --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up')
    if [ -n "$file" ]; then
        nvim "$file"
    fi
}
