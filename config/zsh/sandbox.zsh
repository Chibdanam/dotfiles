# ccsb: launch Claude Code inside @anthropic-ai/sandbox-runtime.
#
# Usage:
#   ccsb [args...]            sandboxed, Claude's normal permission prompts apply
#   ccsb -y [args...]         sandboxed + bypass ALL permission prompts (rely on
#   ccsb --yolo [args...]     the sandbox as the boundary). -y / --yolo / --bypass
#   ccsb --bypass [args...]   are equivalent and must come FIRST.
#
# Settings file resolution order:
#   1. CCSB_SETTINGS env var (explicit override)
#   2. .srt-settings.json walked up from $PWD to /
#   3. ~/.srt-settings.json (global default)
ccsb() {
    # Opt-in bypass: consume a leading -y / --yolo / --bypass flag.
    local bypass=()
    case "$1" in
        -y|--yolo|--bypass)
            bypass=(--permission-mode bypassPermissions)
            shift
            ;;
    esac

    local settings_file=""
    if [[ -n "${CCSB_SETTINGS:-}" ]]; then
        settings_file="$CCSB_SETTINGS"
    else
        local dir="$PWD"
        while [[ "$dir" != "/" && "$dir" != "" ]]; do
            # -s (not -f): skip empty 0-byte ghosts left by a raced sandbox cleanup,
            # which would otherwise be handed to srt as an unparseable settings file.
            if [[ -s "$dir/.srt-settings.json" ]]; then
                settings_file="$dir/.srt-settings.json"
                break
            fi
            dir="${dir:h}"
        done
        if [[ -z "$settings_file" && -s "$HOME/.srt-settings.json" ]]; then
            settings_file="$HOME/.srt-settings.json"
        fi
    fi

    if [[ -z "$settings_file" ]]; then
        echo "ccsb: no .srt-settings.json found in repo, and no ~/.srt-settings.json" >&2
        return 1
    fi

    if (( ${#bypass} )); then
        echo "ccsb: using $settings_file (bypass permissions — sandbox is the boundary)" >&2
    else
        echo "ccsb: using $settings_file" >&2
    fi
    npx --yes @anthropic-ai/sandbox-runtime --settings "$settings_file" \
        claude "${bypass[@]}" "$@"
}

# ccsb-init: drop a starter .srt-settings.json into the current directory.
ccsb-init() {
    if [[ -f .srt-settings.json ]]; then
        echo "ccsb-init: .srt-settings.json already exists here" >&2
        return 1
    fi
    cat > .srt-settings.json <<'JSON'
{
  "network": {
    "allowedDomains": [
      "api.anthropic.com",
      "statsig.anthropic.com"
    ],
    "allowLocalBinding": true
  },
  "filesystem": {
    "allowWrite": [".", "/tmp", "~/.claude", "~/.claude.json", "~/.cache", "~/.npm", "~/.nuget"],
    "denyWrite": ["~/.srt-settings.json", ".srt-settings.json"],
    "denyRead": ["~/.ssh", "~/.aws", "~/.gnupg", "~/.config/gh", "~/.azure", ".env", ".env.*", "secrets", "*.pem", "*.key"]
  }
}
JSON
    echo "Wrote .srt-settings.json. Tune it for this project's needs, then run ccsb."
}
