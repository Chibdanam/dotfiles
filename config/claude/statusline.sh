#!/bin/bash
# Claude Code statusline: machine, model, project, git and context on one line.
# Receives JSON on stdin. It runs on every refresh, so the usual run starts a
# single process (jq); the rest is bash builtins and caches that hold what
# rarely changes: the machine, the Claude account, git (5 s).

US=$'\x1f'
cache=${XDG_RUNTIME_DIR:-/tmp}/claude-statusline-$UID
[[ -d $cache ]] || mkdir -p "$cache"
now=$EPOCHSECONDS

# The plan's limits are kept for local-manager's Claude widget: latest.json at
# most once a minute, and history.jsonl when a percentage moves. jq decides
# from the previous latest.json, which it reads as null when missing or broken.
state=${XDG_STATE_HOME:-$HOME/.local/state}/claude-limits

# jq only extracts: each jq-defined builtin it links (map, join, sub…) costs
# startup time, so the strings are built by interpolation and the model name
# by bash. Fields are \x1f-separated: unlike a tab, it is not IFS whitespace,
# so read keeps empty fields in place.
IFS=$US read -r model_id model_display project_dir cwd used_pct effort style keep entry < <(
    jq -nr '
    def used: [.five_hour.used_percentage?, .seven_day.used_percentage?];
    input as $d
    | (try input catch null) as $last
    | ($d.rate_limits | if type == "object" then . else null end) as $limits
    | (if $limits == null then ""
       elif ($limits | used) != ($last.rate_limits? | used) then "history"
       elif now - ($last.at? // 0) >= 60 then "latest"
       else "" end) as $keep
    | "\($d.model.id? // "")\u001f\($d.model.display_name? // "")\u001f\($d.workspace.project_dir? // "")\u001f\($d.workspace.current_dir? // "")\u001f\($d.context_window.used_percentage? // -1)\u001f\($d.effort.level? // "")\u001f\($d.output_style.name? // "")\u001f\($keep)\u001f\(if $keep != "" then {at: (now | floor), rate_limits: $limits} | tojson else "" end)"
    ' - "$state/latest.json" 2> /dev/null
)

# Family and version read from the model id, so future models need no change:
# claude-opus-5-5[1m] → Opus 5.5, claude-3-5-sonnet-20241022 → Sonnet 3.5,
# us.anthropic.claude-opus-4-1-20250805-v1:0 → Opus 4.1
model= version=
id=${model_id%%[\[@:]*}
if [[ $id == *claude-* ]]; then
    IFS=- read -ra tokens <<< "${id#*claude-}"
    for token in "${tokens[@]}"; do
        if [[ -z $model && $token =~ ^[A-Za-z]+$ ]]; then
            model=${token,,}
            model=${model^}
        elif [[ $token =~ ^[0-9]{1,2}$ ]]; then
            version+=${version:+.}$token
        fi
    done
    [[ -n $model && -n $version ]] && model+=" $version"
fi
if [[ -z $model ]]; then
    # Display name without "Claude " nor its parenthesis: "Opus 5.5 (1M context)" → "Opus 5.5"
    model=${model_display#Claude }
    if [[ $model == *'('*')'* ]]; then
        before=${model%%(*}
        model=${before%"${before##*[![:space:]]}"}${model##*)}
    fi
fi

if [[ -n $keep ]]; then
    {
        [[ -d $state ]] || mkdir -p "$state"
        printf '%s' "$entry" > "$state/latest.json.$$"
        mv -f "$state/latest.json.$$" "$state/latest.json"
        if [[ $keep == history ]]; then
            history=$state/history.jsonl
            printf '%s\n' "$entry" >> "$history"
            if (($(stat -c %s "$history") > 512 * 1024)); then
                mapfile -t lines < "$history"
                printf '%s\n' "${lines[@]:${#lines[@]} / 2}" > "$history.$$"
                mv -f "$history.$$" "$history"
            fi
        fi
    } 2> /dev/null
fi

# Machine: name, virtualization and a color of its own, hashed from the name.
# Only a reboot changes them, so systemd-detect-virt runs once per boot.
host=${HOSTNAME%%.*}
read -r boot 2> /dev/null < /proc/sys/kernel/random/boot_id
IFS=$US read -r cached_boot cached_host virt host_color 2> /dev/null < "$cache/host"
if [[ $cached_boot != "$boot" || $cached_host != "$host" ]]; then
    virt=$(systemd-detect-virt 2> /dev/null)
    case $virt in
        none) virt= ;;
        microsoft) virt=hyper-v ;;
        oracle) virt=vbox ;;
    esac
    hash=0 name=${host,,}
    for ((i = 0; i < ${#name}; i++)); do
        printf -v code '%d' "'${name:i:1}"
        ((hash = (hash * 31 + code) % 1000003))
    done
    palette=(33 37 69 99 135 168 172 208)
    host_color=${palette[hash % ${#palette[@]}]}
    printf '%s\x1f%s\x1f%s\x1f%s\n' "$boot" "$host" "$virt" "$host_color" > "$cache/host"
fi

# Claude account: the organization for a Team or Enterprise seat, "perso"
# otherwise. The cache serves only while strictly newer than the config:
# mtimes tick every few ms, so a config written in the same tick as the cache
# is read again.
config=${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json
org_cache=$cache/org${config//\//%}
org=
if [[ ! -f $config ]]; then
    :
elif [[ $org_cache -nt $config ]]; then
    read -r org < "$org_cache"
else
    org=$(jq -r '.oauthAccount // empty
        | if (.organizationType // "" | test("team|enterprise")) then .organizationName // "" else "perso" end' \
        "$config" 2> /dev/null) && printf '%s\n' "$org" > "$org_cache"
fi

# Git, cached 5 s per directory: one git status gives the branch and counts.
git_dir=${cwd:-$project_dir}
if [[ -n $git_dir ]]; then
    git_cache=$cache/git${git_dir//\//%}
    IFS=$US read -r stamp branch staged modified 2> /dev/null < "$git_cache"
    if ((now - ${stamp:-0} >= 5)); then
        branch= oid= staged=0 modified=0
        while read -r line; do
            case $line in
                '# branch.oid '*) oid=${line#'# branch.oid '} ;;
                '# branch.head '*) branch=${line#'# branch.head '} ;;
                [12]' '*)
                    [[ ${line:2:1} != . ]] && ((staged++))
                    [[ ${line:3:1} != . ]] && ((modified++))
                    ;;
                'u '*) ((modified++)) ;;
            esac
        done < <(git -C "$git_dir" --no-optional-locks status --porcelain=v2 --branch --untracked-files=no 2> /dev/null)
        [[ $branch == '(detached)' ]] && branch=${oid:0:7}
        printf '%s\x1f%s\x1f%s\x1f%s\n' "$now" "$branch" "$staged" "$modified" > "$git_cache"
    fi
fi

# --- Minimal rendering ---
BOLD=$'\e[1m' DIM=$'\e[2m' RST=$'\e[0m'
parts=()

host_text=$'\e[38;5;'"${host_color}m${host}${RST}"
[[ -n $SSH_CONNECTION ]] && host_text="${BOLD}⇄ ${host_text}"
[[ -n $virt ]] && host_text+=" ${DIM}${virt}${RST}"
[[ -n $org ]] && host_text+=" ${DIM}·${RST} ${org}"
parts+=("$host_text")

if [[ -n $model ]]; then
    model_text="${BOLD}${model}${RST}"
    [[ -n $effort ]] && model_text+=$' \e[35m'"${effort}${RST}"
    parts+=("$model_text")
fi
[[ -n $style ]] && parts+=($'\e[36m'"${style}${RST}")
[[ -n $project_dir ]] && parts+=("${project_dir##*/}")

if [[ -n $branch ]]; then
    git_text=$''" ${branch}"
    ((staged > 0)) && git_text+=$' \e[32m+'"${staged}${RST}"
    ((modified > 0)) && git_text+=$' \e[33m~'"${modified}${RST}"
    parts+=("$git_text")
fi

if [[ $used_pct != -1 ]]; then
    used=${used_pct%.*}
    ((used < 0)) && used=0
    ((used > 100)) && used=100
    if ((used >= 90)); then
        color=$'\e[31m'
    elif ((used >= 70)); then
        color=$'\e[33m'
    else
        color=$'\e[32m'
    fi
    parts+=("ctx: ${color}${used}%${RST}")
fi

output=${parts[0]}
for part in "${parts[@]:1}"; do
    output+=" ${DIM}|${RST} ${part}"
done
printf '%s' "$output"
