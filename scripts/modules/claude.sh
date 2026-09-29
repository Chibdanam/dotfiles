#!/bin/bash
set -euo pipefail

_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$_MODULE_DIR")")"
SOURCE_DIR="$DOTFILES_DIR/config/claude"
TARGET_DIR="$HOME/.claude"

install_claude_config() {
    echo "Installing Claude Code configuration..."

    mkdir -p "$TARGET_DIR/skills" "$TARGET_DIR/commands" "$TARGET_DIR/hooks"

    cp "$SOURCE_DIR/settings.json" "$TARGET_DIR/settings.json"
    cp "$SOURCE_DIR/CLAUDE.md" "$TARGET_DIR/CLAUDE.md"
    # CLAUDE.md pulls it in with @RTK.md
    cp "$SOURCE_DIR/RTK.md" "$TARGET_DIR/RTK.md"
    cp "$SOURCE_DIR/statusline.sh" "$TARGET_DIR/statusline.sh"
    chmod +x "$TARGET_DIR/statusline.sh"

    if [[ -d "$SOURCE_DIR/skills" ]]; then
        cp -R "$SOURCE_DIR/skills/." "$TARGET_DIR/skills/"
    fi
    cp "$SOURCE_DIR/commands/"*.md "$TARGET_DIR/commands/"

    # PreToolUse(Bash) hook from settings.json: rtk plus the dotnet rewrites
    # rtk lacks until rtk-ai/rtk#3300. The daily cron tells when to drop it.
    cp "$SOURCE_DIR/hooks/rtk-hook.sh" "$TARGET_DIR/hooks/rtk-hook.sh"
    chmod +x "$TARGET_DIR/hooks/rtk-hook.sh"
    mkdir -p "$HOME/.local/bin"
    cp "$DOTFILES_DIR/bin/rtk-3300-check.sh" "$HOME/.local/bin/rtk-3300-check.sh"
    chmod +x "$HOME/.local/bin/rtk-3300-check.sh"
    if command -v crontab &> /dev/null && ! crontab -l 2>/dev/null | grep -F rtk-3300-check.sh > /dev/null; then
        (crontab -l 2>/dev/null || true; echo "0 10 * * * $HOME/.local/bin/rtk-3300-check.sh") | crontab -
    fi

    # settings.json hooks call both on every prompt / Bash command
    local bin
    for bin in rtk codegraph; do
        if ! command -v "$bin" &> /dev/null; then
            add_notice "Install $bin: the Claude Code hooks in ~/.claude/settings.json call it."
        fi
    done

    echo "Claude Code configuration installed!"
    echo "  - Settings:  $TARGET_DIR/settings.json"
    echo "  - CLAUDE.md: $TARGET_DIR/CLAUDE.md"
    echo "  - RTK.md:    $TARGET_DIR/RTK.md"
    echo "  - Statusline:$TARGET_DIR/statusline.sh"
    echo "  - Skills:    $TARGET_DIR/skills"
    echo "  - Commands:  $TARGET_DIR/commands"
    echo "  - Hooks:     $TARGET_DIR/hooks"
}

install_claude_config
