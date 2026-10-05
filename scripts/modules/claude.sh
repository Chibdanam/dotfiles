#!/bin/bash
set -euo pipefail

_MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$_MODULE_DIR")")"
SOURCE_DIR="$DOTFILES_DIR/config/claude"
TARGET_DIR="$HOME/.claude"

# Deep merge: a key the layer sets wins, objects merge key by key, arrays
# (permission lists) gain the layer's entries.
merge_json() {
    if ! command -v jq &> /dev/null; then
        echo "  [WARN] jq not found: $(basename "$2") ignored" >&2
        cat "$1"
        return
    fi
    jq -s '
        def merge($b):
            . as $a
            | if ($a | type) == "object" and ($b | type) == "object" then
                reduce ($b | keys_unsorted[]) as $k ($a; .[$k] = ($a[$k] | merge($b[$k])))
            elif ($a | type) == "array" and ($b | type) == "array" then
                $a + ($b - $a)
            else $b end;
        .[1] as $layer | .[0] | merge($layer)
    ' "$1" "$2"
}

# By "## " section: a heading the layer repeats has its section replaced,
# new headings are appended. Text above the layer's first "## " is not merged.
merge_markdown() {
    awk '
        function rtrim(s) { sub(/\n+$/, "", s); return s }
        function put(s) { out = out s "\n" }
        FNR == NR {
            if (/^## /) { head = $0; order[++n] = head; body[head] = "" }
            if (head != "") body[head] = body[head] $0 "\n"
            next
        }
        /^## / {
            skip = 0
            if ($0 in body) { put(rtrim(body[$0])); put(""); done[$0] = 1; skip = 1; next }
        }
        !skip { put($0) }
        END {
            for (i = 1; i <= n; i++) {
                if (!(order[i] in done)) { put(""); put(rtrim(body[order[i]])) }
            }
            gsub(/\n\n\n+/, "\n\n", out)
            sub(/\n+$/, "\n", out)
            printf "%s", out
        }
    ' "$2" "$1"
}

# A branch layered on this one (a work machine fork) ships NAME.local.EXT
# next to a shared file instead of editing it.
install_layered() {
    local name="$1" merge="$2"
    local layer="$SOURCE_DIR/${name%.*}.local.${name##*.}"

    if [[ -f "$layer" ]]; then
        "$merge" "$SOURCE_DIR/$name" "$layer" > "$TARGET_DIR/$name"
        echo "  - $name merged with $(basename "$layer")"
    else
        cp "$SOURCE_DIR/$name" "$TARGET_DIR/$name"
    fi
}

install_claude_config() {
    echo "Installing Claude Code configuration..."

    mkdir -p "$TARGET_DIR/skills" "$TARGET_DIR/commands"

    install_layered settings.json merge_json
    install_layered CLAUDE.md merge_markdown

    cp "$SOURCE_DIR/statusline.sh" "$TARGET_DIR/statusline.sh"
    chmod +x "$TARGET_DIR/statusline.sh"

    if [[ -d "$SOURCE_DIR/skills" ]]; then
        cp -R "$SOURCE_DIR/skills/." "$TARGET_DIR/skills/"
    fi
    cp "$SOURCE_DIR/commands/"*.md "$TARGET_DIR/commands/"

    # Tool integrations patch settings.json and CLAUDE.md themselves, and both
    # were just overwritten above, so re-run each installer when its tool is
    # present. Their output changes with every tool release: not versioned.
    if command -v herdr &> /dev/null; then
        herdr integration install claude
        echo "  - herdr integration"
    fi
    if command -v rtk &> /dev/null; then
        rtk init -g --auto-patch
        echo "  - rtk hook"
    fi
    if command -v codegraph &> /dev/null; then
        codegraph install --target claude --location global --yes
        echo "  - codegraph MCP + hook"
    fi

    echo "Claude Code configuration installed!"
    echo "  - Settings:  $TARGET_DIR/settings.json"
    echo "  - CLAUDE.md: $TARGET_DIR/CLAUDE.md"
    echo "  - Statusline:$TARGET_DIR/statusline.sh"
    echo "  - Skills:    $TARGET_DIR/skills"
    echo "  - Commands:  $TARGET_DIR/commands"
}

install_claude_config
