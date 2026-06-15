#!/usr/bin/env bash
# Tmux sessionizer - select a project and attach/create its session. Usable
# both as a standalone command (zsh `f`) and from a tmux popup (prefix + j);
# when run inside tmux it switches the client, otherwise it attaches.
#
# Search roots: ~/dev is always listed. Extra roots -- for monorepos whose
# projects live in nested folders -- are read from
# ~/.config/zsh/fuzzy-dir.local.txt (one path per line; '#' comments and blank
# lines ignored). Dot-folders and git-ignored paths (bin/, obj/, node_modules/,
# ...) are pruned automatically. See config/zsh/fuzzy-dir.example.txt.
set -euo pipefail

roots_file="${ZDOTDIR:-$HOME/.config/zsh}/fuzzy-dir.local.txt"

# ~/dev is always searched; append any extra roots from the local file.
roots=("$HOME/dev")
if [ -r "$roots_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"                      # strip inline / full-line comments
        line="${line//[[:space:]]/}"            # strip surrounding whitespace
        [ -z "$line" ] && continue
        case "$line" in
            "~/"*) line="$HOME/${line#\~/}" ;;   # expand a leading ~/
            /*)    ;;                             # absolute path, keep as-is
            *)     line="$HOME/$line" ;;          # otherwise relative to $HOME
        esac
        roots+=("${line%/}")                     # drop any trailing slash
    done < "$roots_file"
fi

# Immediate subdirectories of every root, with dot-folders and git-ignored
# paths (bin/, obj/, node_modules/, ...) pruned, printed ~/dev-relative (so
# ~/dev/peren/foo -> "peren/foo"), de-duplicated, filesystem order preserved.
gather_dirs() {
    local root dirs ignored
    for root in "${roots[@]}"; do
        [ -d "$root" ] || continue
        dirs=$(find "$root" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf '%p\n' 2>/dev/null) || true
        if [ -z "$dirs" ]; then
            continue
        fi
        # Drop anything git ignores, but only when the root is inside a repo.
        if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            ignored=$(printf '%s\n' "$dirs" | git -C "$root" check-ignore --stdin 2>/dev/null || true)
            if [ -n "$ignored" ]; then
                dirs=$(printf '%s\n' "$dirs" | grep -vxF -f <(printf '%s\n' "$ignored") || true)
            fi
        fi
        printf '%s\n' "$dirs"
    done | sed "s|^$HOME/dev/||" | awk 'NF && !seen[$0]++'
}

# Map each project session to when it was last attached so projects with an
# open (or most recently focused) session float to the top; everything else
# keeps its filesystem order below them. The session we're currently in (if
# any) is pushed to the very bottom -- we're already there.
sessions=$(tmux list-sessions -F '#{session_name} #{session_last_attached}' 2>/dev/null || true)
current=""
[ -n "${TMUX:-}" ] && current=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)

dir=$(gather_dirs | \
    awk -v sess="$sessions" -v cur="$current" '
        BEGIN {
            n = split(sess, lines, "\n")
            for (i = 1; i <= n; i++) {
                split(lines[i], a, " ")
                if (a[1] != "") ts[a[1]] = a[2]
            }
        }
        {
            name = $0; sub(/.*\//, "", name)   # session name = basename
            if (name == cur) key = -1          # current session -> bottom
            else key = (name in ts) ? ts[name] : 0
            print key "\t" $0
        }' | \
    sort -s -k1,1nr | cut -f2- | \
    fzf --preview "eza --tree --level=1 --color=always $HOME/dev/{}" \
        --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up')

[ -z "$dir" ] && exit 0

# Session name is the project's basename, made tmux-safe (so ~/dev/peren/foo
# -> "foo"; dots and colons -- special in tmux targets -- become underscores).
session_name="${dir##*/}"
session_name="${session_name//[.:]/_}"
project_path="$HOME/dev/$dir"

if ! tmux has-session -t "$session_name" 2>/dev/null; then
    # Create new session with 4 windows
    tmux new-session -d -s "$session_name" -c "$project_path" -n "Claude"
    tmux new-window -t "$session_name" -c "$project_path" -n "nvim"
    tmux new-window -t "$session_name" -c "$project_path" -n "run"
    tmux new-window -t "$session_name" -c "$project_path" -n "zsh"

    # Split the 'run' window into 2 side-by-side panes
    tmux split-window -h -t "$session_name:run"

    # Select the first window
    tmux select-window -t "$session_name:Claude"
fi

if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$session_name"
else
    tmux attach-session -t "$session_name"
fi
