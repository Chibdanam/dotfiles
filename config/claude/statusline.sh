#!/usr/bin/env bash
# Claude Code statusline — project context and session metrics.
# Receives JSON on stdin; outputs a single minimal line.

input=$(cat)

# Parse all fields in one python3 call
IFS=$'\t' read -r model_display project_dir cwd used_pct effort_level output_style < <(
  echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
m = d.get('model', {}).get('display_name', '')
p = d.get('workspace', {}).get('project_dir', '')
c = d.get('workspace', {}).get('current_dir', '')
u = d.get('context_window', {}).get('used_percentage')
e = (d.get('effort') or {}).get('level') or '-'
s = (d.get('output_style') or {}).get('name') or '-'
print(f'{m}\t{p}\t{c}\t{u if u is not None else -1}\t{e}\t{s}')
"
)

# '-' stands for an absent field: read collapses consecutive tabs
[[ "$effort_level" == "-" ]] && effort_level=""
[[ "$output_style" == "-" ]] && output_style=""

# Short model name: "Claude Opus 4.6" → "Opus"
model_short="${model_display#Claude }"
model_short="${model_short%% *}"

# Project folder name
project_name=""
[[ -n "$project_dir" ]] && project_name=$(basename "$project_dir")

# Git info with caching (refresh every 5s)
git_branch=""
git_staged=0
git_modified=0
cache_file="/tmp/claude-statusline-git-cache"
git_dir="${cwd:-$project_dir}"

if [[ -n "$git_dir" ]]; then
    now=$(date +%s)
    use_cache=false

    if [[ -f "$cache_file" ]]; then
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)
        if (( now - cache_mtime < 5 )); then
            cached_dir=$(head -1 "$cache_file")
            if [[ "$cached_dir" == "$git_dir" ]]; then
                use_cache=true
                IFS=$'\t' read -r git_branch git_staged git_modified < <(sed -n '2p' "$cache_file")
            fi
        fi
    fi

    if ! $use_cache; then
        git_branch=$(git -C "$git_dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -n "$git_branch" ]]; then
            git_staged=$(git -C "$git_dir" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
            git_modified=$(git -C "$git_dir" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        fi
        printf '%s\n%s\t%s\t%s\n' "$git_dir" "$git_branch" "$git_staged" "$git_modified" > "$cache_file"
    fi
fi

# --- Minimal rendering ---
DIM="\033[2m"
RST="\033[0m"
parts=()

if [[ -n "$model_short" ]]; then
    model_text="\033[1m${model_short}${RST}"
    [[ -n "$effort_level" ]] && model_text+=" \033[35m${effort_level}${RST}"
    parts+=("${model_text}")
fi
[[ -n "$output_style" ]] && parts+=("\033[36m${output_style}${RST}")
[[ -n "$project_name" ]] && parts+=("${project_name}")

if [[ -n "$git_branch" ]]; then
    git_text=$'\uE0A0'" ${git_branch}"
    (( git_staged > 0 )) && git_text+=" \033[32m+${git_staged}${RST}"
    (( git_modified > 0 )) && git_text+=" \033[33m~${git_modified}${RST}"
    parts+=("${git_text}")
fi

if [[ "$used_pct" != "-1" ]]; then
    used_int=${used_pct%.*}
    (( used_int < 0 )) && used_int=0
    (( used_int > 100 )) && used_int=100

    if (( used_int >= 90 )); then
        ctx_color="\033[31m"
    elif (( used_int >= 70 )); then
        ctx_color="\033[33m"
    else
        ctx_color="\033[32m"
    fi
    parts+=("ctx: ${ctx_color}${used_int}%${RST}")
fi

output=""
for (( i = 0; i < ${#parts[@]}; i++ )); do
    (( i > 0 )) && output+=" ${DIM}|${RST} "
    output+="${parts[i]}"
done

printf '%b' "$output"
