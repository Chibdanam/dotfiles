#!/usr/bin/env bash
# =============================================================================
# herdr space sessionizer  (bound to prefix+j in config.toml)
# =============================================================================
# fzf picker over your project directories -> create-or-focus a herdr space,
# named after the directory. Ported from a tmux-sessionizer workflow:
#   - tmux "switch to existing session or create it"  ->  focus/create a space
#   - runs in a temporary herdr pane (type = "pane"); the pane closes on exit.
#
# Pass a path as $1 to skip the picker and jump straight to that directory.
#
# Search roots: ~/dev is always listed. Extra roots -- for monorepos whose
# projects live in nested folders -- are read from
# ~/.config/zsh/fuzzy-dir.local.txt (one path per line; '#' comments and blank
# lines ignored), the same file the tmux sessionizer uses. Each root is scanned
# ONE level deep; dot-folders and git-ignored paths (bin/, obj/, node_modules/,
# ...) are pruned automatically. See config/zsh/fuzzy-dir.example.txt.
# -----------------------------------------------------------------------------

set -uo pipefail

roots_file="${ZDOTDIR:-$HOME/.config/zsh}/fuzzy-dir.local.txt"

# ~/dev is always searched; append any extra roots from the local file.
roots=("$HOME/dev")
if [ -r "$roots_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"                      # strip inline / full-line comments
    line="${line//[[:space:]]/}"            # strip surrounding whitespace
    [ -z "$line" ] && continue
    case "$line" in
      "~/"*) line="$HOME/${line#\~/}" ;;    # expand a leading ~/
      /*)    ;;                             # absolute path, keep as-is
      *)     line="$HOME/$line" ;;          # otherwise relative to $HOME
    esac
    roots+=("${line%/}")                    # drop any trailing slash
  done < "$roots_file"
fi

# Immediate subdirectories of every root (absolute paths), with dot-folders
# and git-ignored paths (bin/, obj/, node_modules/, ...) pruned, de-duplicated.
list_dirs() {
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
  done | awk 'NF && !seen[$0]++'
}

# --- pick a directory -------------------------------------------------------
if [[ $# -ge 1 ]]; then
  selected="$1"
else
  selected="$(list_dirs | fzf --prompt='herdr space> ' --reverse --height=100% \
                              --border --preview 'ls -la {}' --preview-window=right,40%)"
fi

[[ -z "${selected:-}" ]] && exit 0          # picker cancelled -> do nothing
selected="${selected%/}"
if [[ ! -d "$selected" ]]; then
  echo "Not a directory: $selected" >&2
  sleep 1.5
  exit 1
fi

# --- derive the space label (tmux-sessionizer style) ------------------------
name="$(basename "$selected" | tr ' .' '__')"

# --- create-or-focus --------------------------------------------------------
existing=""
if command -v jq >/dev/null 2>&1; then
  existing="$(herdr workspace list 2>/dev/null \
    | jq -r --arg n "$name" '.result.workspaces[]? | select(.label==$n) | .workspace_id' \
    | head -n1)"
fi

if [[ -n "$existing" ]]; then
  herdr workspace focus "$existing" >/dev/null 2>&1
else
  herdr workspace create --cwd "$selected" --label "$name" --focus >/dev/null 2>&1
fi
