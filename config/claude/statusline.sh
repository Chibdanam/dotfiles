#!/usr/bin/env bash
# Claude Code statusline — project context and session metrics.
# Receives JSON on stdin; outputs a single minimal line.

input=$(cat)

# Parse all fields in one python3 call. Fields are \x1f-separated: unlike
# a tab, it is not IFS whitespace, so read keeps empty fields in place.
IFS=$'\x1f' read -r model_name project_dir cwd used_pct effort_level output_style < <(
  echo "$input" | python3 -c "
import sys, json, re
d = json.load(sys.stdin)

# Family and version read from the model id, so future models need no change:
# claude-opus-5-5[1m] → Opus 5.5, claude-3-5-sonnet-20241022 → Sonnet 3.5,
# us.anthropic.claude-opus-4-1-20250805-v1:0 → Opus 4.1
def model_name(model):
    mid = re.split(r'[\[@:]', model.get('id') or '')[0]
    if 'claude-' in mid:
        tokens = mid.split('claude-', 1)[1].split('-')
        family = next((t for t in tokens if t.isalpha()), '')
        version = '.'.join(t for t in tokens if t.isdigit() and len(t) <= 2)
        if family:
            return f'{family.capitalize()} {version}'.strip()
    name = (model.get('display_name') or '').removeprefix('Claude ')
    return re.sub(r'\s*\(.*\)', '', name)

m = model_name(d.get('model') or {})
p = d.get('workspace', {}).get('project_dir', '')
c = d.get('workspace', {}).get('current_dir', '')
u = d.get('context_window', {}).get('used_percentage')
e = (d.get('effort') or {}).get('level') or ''
s = (d.get('output_style') or {}).get('name') or ''
print('\x1f'.join([m, p, c, str(u if u is not None else -1), e, s]))
"
)

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
                IFS=$'\x1f' read -r git_branch git_staged git_modified < <(sed -n '2p' "$cache_file")
            fi
        fi
    fi

    if ! $use_cache; then
        git_branch=$(git -C "$git_dir" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -n "$git_branch" ]]; then
            git_staged=$(git -C "$git_dir" --no-optional-locks diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
            git_modified=$(git -C "$git_dir" --no-optional-locks diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        fi
        printf '%s\n%s\x1f%s\x1f%s\n' "$git_dir" "$git_branch" "$git_staged" "$git_modified" > "$cache_file"
    fi
fi

# --- Minimal rendering ---
DIM="\033[2m"
RST="\033[0m"
parts=()

if [[ -n "$model_name" ]]; then
    model_text="\033[1m${model_name}${RST}"
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
