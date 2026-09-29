#!/bin/sh
# Cron quotidien (10h) : le wrapper ~/.claude/hooks/rtk-hook.sh peut-il être retiré ?
# Critère décisif : le rtk installé réécrit-il `dotnet test` (issue rtk-ai/rtk#3300).
PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin"
DIR="$HOME/.local/state/rtk-3300"
mkdir -p "$DIR"

issue=$(curl -sf --max-time 20 https://api.github.com/repos/rtk-ai/rtk/issues/3300 | jq -r '.state // "unknown"')
[ -n "$issue" ] || issue=unreachable
ver=$(rtk --version 2>/dev/null | awk '{print $2}')
if rtk rewrite "dotnet test Foo.csproj" >/dev/null 2>&1; then local_ok=yes; else local_ok=no; fi

if   [ "$local_ok" = yes ];   then status=resolved
elif [ "$issue" = closed ];   then status=closed-upstream
else                               status=pending
fi

printf '%s issue=%s rtk=%s local_rewrite=%s checked=%s\n' "$status" "$issue" "$ver" "$local_ok" "$(date -Iseconds)" > "$DIR/status"
printf '%s %s issue=%s rtk=%s local_rewrite=%s\n' "$(date -Iseconds)" "$status" "$issue" "$ver" "$local_ok" >> "$DIR/history.log"
