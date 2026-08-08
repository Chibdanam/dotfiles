#!/bin/bash
set -euo pipefail

_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$_MODULE_DIR")")"
SOURCE_DIR="$DOTFILES_DIR/config/claude"
TARGET_DIR="$HOME/.claude"

install_claude_config() {
    echo "Installing Claude Code configuration..."

    mkdir -p "$TARGET_DIR/skills"

    # Machine policy lives in an untracked, seed-once file (same pattern as
    # ~/.gitconfig.local): tracked settings.json is the shared baseline,
    # settings.local.json holds per-machine overrides.
    local settings_local="$TARGET_DIR/settings.local.json"
    if [[ ! -e "$settings_local" ]]; then
        cp "$SOURCE_DIR/settings.local.example.json" "$settings_local"
        echo "  - Seeded $settings_local (edit for machine policy)"
    else
        echo "  - Kept existing $settings_local"
    fi

    # Claude Code only reads settings.local.json at project level, not in
    # ~/.claude, so the installed settings.json is generated here: objects
    # deep-merge (local scalars win), permission arrays union, and a rule
    # promoted to allow locally is dropped from the baseline ask list.
    if command -v jq &> /dev/null; then
        jq -s '.[0] as $base | .[1] as $local
          | ($base * $local)
          | .permissions.allow = ((($base.permissions.allow // []) + ($local.permissions.allow // [])) | unique)
          | .permissions.ask   = (((($base.permissions.ask  // []) + ($local.permissions.ask  // [])) | unique) - ($local.permissions.allow // []))
          | .permissions.deny  = ((($base.permissions.deny  // []) + ($local.permissions.deny  // [])) | unique)
        ' "$SOURCE_DIR/settings.json" "$settings_local" > "$TARGET_DIR/settings.json"
    else
        echo "  ! jq not found: installed baseline settings.json without local overrides"
        cp "$SOURCE_DIR/settings.json" "$TARGET_DIR/settings.json"
    fi

    cp "$SOURCE_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    cp "$SOURCE_DIR/statusline.sh" "$TARGET_DIR/statusline.sh"
    chmod +x "$TARGET_DIR/statusline.sh"

    if [[ -d "$SOURCE_DIR/skills" ]]; then
        cp -R "$SOURCE_DIR/skills/." "$TARGET_DIR/skills/"
    fi

    echo "Claude Code configuration installed!"
    echo "  - Settings:  $TARGET_DIR/settings.json"
    echo "  - CLAUDE.md: $TARGET_DIR/CLAUDE.md"
    echo "  - Statusline:$TARGET_DIR/statusline.sh"
    echo "  - Skills:    $TARGET_DIR/skills"
}

install_claude_config
