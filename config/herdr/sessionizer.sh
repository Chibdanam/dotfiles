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
# Each root below is scanned ONE level deep, so listing a monorepo root
# (e.g. ~/dev/peren) surfaces its subprojects as individually pickable spaces.
# Add more roots to taste.
# -----------------------------------------------------------------------------

set -uo pipefail

SEARCH_DIRS=(
  "$HOME/dev"          # top-level projects
  "$HOME/dev/peren"    # monorepo: pick its subprojects directly (CMS, Demat, ...)
)

# Directory names to hide (build/storage output not caught by .gitignore).
EXCLUDE='obj|bin|node_modules|__blobstorage__|__queuestorage__|AzurePipeline'

list_dirs() {
  local root
  for root in "${SEARCH_DIRS[@]}"; do
    [[ -d "$root" ]] || continue
    if command -v fd >/dev/null 2>&1; then
      fd --exact-depth 1 --type d --absolute-path . "$root"
    else
      find "$root" -mindepth 1 -maxdepth 1 -type d
    fi
  done 2>/dev/null | grep -vEi "/($EXCLUDE)/?$" | sort -u
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
