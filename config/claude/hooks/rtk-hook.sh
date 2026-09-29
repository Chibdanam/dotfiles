#!/bin/sh
# PreToolUse(Bash) : délègue à `rtk hook claude`, puis complète ce que rtk ne réécrit pas encore.
# Aujourd'hui : dotnet test/restore/format (rtk ne route que `dotnet build`, cf. rtk-ai/rtk#3300).
# Le wrapper devient un simple passthrough dès que rtk gère ces commandes lui-même.
# ~/.local/bin/rtk-3300-check.sh (cron 10h) écrit l'état dans $STATE ; quand il vaut "resolved",
# remplacer ce script par `rtk hook claude` dans ~/.claude/settings.json.
PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
STATE="$HOME/.local/state/rtk-3300/status"

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
out=$(printf '%s' "$input" | rtk hook claude)

case "$cmd" in
  dotnet\ test*|dotnet\ restore*|dotnet\ format*|timeout\ *dotnet\ test*|timeout\ *dotnet\ restore*|timeout\ *dotnet\ format*)
    if [ -z "$out" ]; then
      new=$(printf '%s' "$cmd" | sed -E 's/^((timeout [0-9]+ )?)dotnet (test|restore|format)\b/\1rtk dotnet \3/')
      out=$(jq -cn --arg c "$new" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecisionReason:"RTK auto-rewrite (wrapper rtk#3300)",updatedInput:{command:$c}}}')
    fi
    if [ -f "$STATE" ]; then
      case "$(cut -d' ' -f1 "$STATE")" in
        resolved)        msg="rtk#3300 résolu : rtk réécrit dotnet test nativement. Remplace ~/.claude/hooks/rtk-hook.sh par 'rtk hook claude' dans ~/.claude/settings.json." ;;
        closed-upstream) msg="rtk#3300 fermée upstream mais le rtk local ne réécrit pas encore dotnet test : mets rtk à jour, puis retire le wrapper." ;;
      esac
      [ -n "$msg" ] && out=$(printf '%s' "${out:-{\}}" | jq -c --arg m "$msg" '. + {systemMessage:$m}')
    fi
    ;;
esac

[ -n "$out" ] && printf '%s\n' "$out"
exit 0
