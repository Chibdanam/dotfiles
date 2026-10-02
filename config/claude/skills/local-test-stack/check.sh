#!/usr/bin/env bash
# Prove the local peren stack runs the code of one tree before a test run reads it.
# usage: check.sh pre|post [tree=~/dev/peren] [main tree=~/dev/peren]
#   post  the stack is up: every app runs from the tree on its current build, Cosmos is intact,
#         ApiTester points at the tree. All OK = run the tests, nothing to restart.
#   pre   the stack is down (mise r stop): ignored files copied into a worktree, launch
#         profiles, Cosmos up with its database. Then mise r start from the tree, then post.
set -u
phase=${1:?pre|post}
T=$(realpath "${2:-$HOME/dev/peren}")
M=$(realpath "${3:-$HOME/dev/peren}")
APPS="CoreWebApi ArchiveWebApi DematProcessor InvoiceGenerationWebJobs"
WS=Demat/Demat/PrinterTesterApp/ApiTester
AT=$HOME/dev/zz-api-tester
DD=$HOME/dev/dematDashboard
ko=0
ok()   { printf '  OK    %s\n' "$*"; }
info() { printf '  INFO  %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; }
bad()  { printf '  KO    %s\n' "$*"; ko=$((ko + 1)); }

# The apphost of an app, from whichever tree started it.
pids_of() { pgrep -f "/$1/bin/Debug/net[0-9.]*/$1( |\$)"; }
started_at() { echo $(($(date +%s) - $(ps -o etimes= -p "$1"))); }

# Project directories an app is built from: its own and every ProjectReference, recursively.
closure() {
  local todo=("$T/$1/$1.csproj") seen=" " p ref
  while [ ${#todo[@]} -gt 0 ]; do
    p=$(realpath -m "${todo[0]}"); todo=("${todo[@]:1}")
    case $seen in *" $p "*) continue ;; esac
    seen="$seen$p "
    while read -r ref; do todo+=("$(dirname "$p")/${ref//\\//}"); done \
      < <(grep -o 'ProjectReference Include="[^"]*"' "$p" 2>/dev/null | sed 's/.*Include="//; s/"$//')
  done
  for p in $seen; do dirname "$p"; done
}

# cosmos-init is idempotent and never reads a document: "created" means it was missing.
cosmos_probe() {
  local script=$T/Scripts/cosmos-init.py out
  [ -f "$script" ] || script=$M/Scripts/cosmos-init.py
  if ! out=$(python3 "$script" 2>&1) || grep -q FAILED <<<"$out"; then
    bad "cosmos-init a échoué → cd $M; mise r cosmos:restart"
    printf '%s\n' "$out" | tail -3 | sed 's/^/        /'
  elif grep -q ' created' <<<"$out"; then
    $1 "base Archive recréée : elle avait disparu, les reçus locaux sont perdus (le dire)"
  else
    ok "Cosmos : base Archive et conteneurs présents"
  fi
}

echo "== $phase sur $T"

if [ "$phase" = pre ]; then
  if [ "$T" != "$M" ]; then
    for f in CoreWebApi/appsettings.shared.Local.json certs/aspnet-dev.pfx certs/aspnet-dev.pem certs/aspnet-dev.key \
      $WS/Config/collection.environment.json $WS/Config/collection.settings.json \
      $WS/Config/collection.global.json $WS/Config/collection.local.json mise.toml compose.wsl.yml; do
      # Never overwrite: tokens refreshed in the worktree are newer than the main tree's.
      if [ -f "$T/$f" ]; then continue; fi
      if [ -f "$M/$f" ]; then mkdir -p "$(dirname "$T/$f")"; cp "$M/$f" "$T/$f"; info "copié depuis $M : $f"
      else bad "$f absent des deux arbres"; fi
    done
  fi
  for app in CoreWebApi ArchiveWebApi; do
    grep -q '"WSL-CLI"' "$T/$app/Properties/launchSettings.json" 2>/dev/null \
      || bad "$app sans profil WSL-CLI : il partirait en Production sur le port 5000"
  done
  # mise r start skips an app that runs from any tree, so a survivor would stay as it is.
  for app in $APPS; do
    for pid in $(pids_of "$app"); do bad "$app tourne encore (pid $pid) → mise r stop core archive demat invoice"; done
  done
  state=$(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' peren-cosmos 2>/dev/null)
  if [ "$state" != "running healthy" ]; then
    bad "peren-cosmos : ${state:-absent} → cd $M; mise r infra:up, attendre healthy (~3 min)"
  elif docker logs --tail 300 peren-cosmos 2>&1 | grep -q 'evaluation period has expired'; then
    bad "licence de l'émulateur expirée → cd $M; docker compose -f compose.wsl.yml pull cosmos; mise r cosmos:restart"
  else
    cosmos_probe info
  fi
fi

if [ "$phase" = post ]; then
  oldest=$(date +%s)
  for app in $APPS; do
    pids=$(pids_of "$app")
    if [ -z "$pids" ]; then bad "$app ne tourne pas"; continue; fi
    bin=$T/$app/bin/Debug/net8.0
    for pid in $pids; do
      exe=$(tr '\0' '\n' < "/proc/$pid/cmdline" | head -1)
      start=$(started_at "$pid")
      [ "$start" -lt "$oldest" ] && oldest=$start
      case $exe in "$T"/*) bin=$(dirname "$exe") ;; *) bad "$app pid $pid tourne depuis $exe"; continue ;; esac
      newer=$(find "$bin" -maxdepth 1 -name '*.dll' -newermt "@$start" | head -1)
      # shellcheck disable=SC2046
      edited=$(find $(closure "$app") \( -name bin -o -name obj \) -prune -o -type f \
        \( -name '*.cs' -o -name '*.csproj' -o -name 'appsettings*.json' \) -newermt "@$start" -print 2>/dev/null)
      if [ -n "$newer" ]; then bad "$app : rebuild après son démarrage ($(basename "$newer")), le process tourne sur l'ancien → relancer"
      elif [ -n "$edited" ]; then bad "$app : $(wc -l <<<"$edited") source(s) modifiée(s) après son démarrage, dont ${edited%%$'\n'*} → relancer"
      else ok "$app pid $pid : $T, build courant, démarré $(date -d "@$start" '+%d/%m %H:%M')"; fi
    done
    case $app in
      CoreWebApi | ArchiveWebApi)
        # mise r start links latest.log a moment before it launches the app.
        log=$HOME/logs/$app/latest.log
        lag=$((start - $(stat -c %Y "$log" 2>/dev/null || echo 0)))
        if [ "$lag" -lt -5 ] || [ "$lag" -gt 300 ]; then warn "$app : pas de log de mise r start pour ce process"
        elif grep -q "Content root path: $T/$app" "$log" && grep -q "Now listening on" "$log"; then ok "$app : content root $T/$app, à l'écoute"
        else bad "$app : content root ≠ $T/$app ou pas encore à l'écoute ($log)"; fi ;;
      *)
        # Workers read their config from bin/, where the build copies the local file only if it existed.
        cmp -s "$T/CoreWebApi/appsettings.shared.Local.json" "$bin/appsettings.shared.Local.json" \
          || bad "$app : bin/appsettings.shared.Local.json absent ou périmé → rebuild" ;;
    esac
  done

  started=$(date -d "$(docker inspect -f '{{.State.StartedAt}}' peren-cosmos 2>/dev/null || echo 1970-01-01)" +%s)
  if [ "$started" -gt "$oldest" ]; then bad "peren-cosmos a redémarré après les apps → cosmos-init puis relancer les 4 apps"
  elif docker logs --since "$oldest" peren-cosmos 2>&1 | grep -qE 'Capturing a dump|fatal error'; then
    bad "peren-cosmos a planté en place depuis le démarrage des apps (Docker dit healthy) → cd $M; mise r cosmos:restart puis relancer les 4 apps"
  else cosmos_probe bad; fi

  if [ -d "$AT" ]; then
    info "ApiTester dev : $(git -C "$AT" branch --show-current) $(git -C "$AT" rev-parse --short HEAD), $(git -C "$AT" status --porcelain | wc -l) fichier(s) modifié(s)"
    (cd "$AT" && mise run status 2>/dev/null) | sed 's/^ */        /'
    info "Postman CLI : $(cd "$AT" && mise exec -- postman --version 2>/dev/null)"
    args=()
    if [ "$T" != "$M" ]; then
      args=(-workspace "$T/$WS" -postmanPath "$T/postman/collections/Scenario de Test"
        -postmanEnvironment "$T/postman/environments/Local Demat.environment.yaml")
    fi
    paths=$(cd "$AT" && mise exec -- dotnet run --project src/ApiTester --no-build -- --print-paths "${args[@]}" 2>/dev/null | grep -E '^[a-zA-Z]+=')
    root=$(sed -n 's/^root=//p' <<<"$paths"); collection=$(sed -n 's/^collection=//p' <<<"$paths")
    case $root in "$T"/*) ok "workspace : $root" ;; *) bad "workspace : ${root:-non résolu} ≠ $T" ;; esac
    case $collection in
      "") info "collection non affichée par ce build de l'ApiTester (feature/headless-workspace non mergée)" ;;
      "$T"/*) ok "collection : $collection" ;;
      *) bad "collection : $collection ≠ $T" ;;
    esac
    dirty=$(git -C "$T" status --porcelain -- "$WS/Results" | wc -l)
    [ "$dirty" -eq 0 ] && ok "Results/ propre" || warn "Results/ : $dirty capture(s) déjà modifiée(s), le diff du run les mélangera"
    echo "  RUN   cd $AT"
    if [ "$T" = "$M" ]; then
      echo "        mise run headless --test-set Demat --folder <dossier>"
    elif grep -q 'flag "--workspace' "$AT/mise.toml"; then
      echo "        mise run headless --test-set Demat --folder <dossier> --workspace '$T/$WS' \\"
      echo "          --postman-path '${args[3]}' --environment '${args[5]}'"
    else
      echo "        mise exec -- dotnet run --project src/ApiTester -- ${args[*]:0:2} -headless -postmanRunMode converted \\"
      echo "          -postmanPath '${args[3]}' -postmanEnvironment '${args[5]}' -testSet Demat -folder <dossier>"
    fi
  fi

  if [ -d "$DD" ]; then
    # The last reflog entry that rewrote the working tree; a plain commit does not.
    moved=$(git -C "$DD" reflog -n 100 --date=unix --format='%gd %gs' \
      | grep -m1 -E '^[^ ]+ (checkout|reset|rebase|merge|pull|commit \(merge\))' | sed 's/.*@{\([0-9]*\)}.*/\1/')
    for port in 4300 4302; do
      pid=$(ss -ltnpH "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
      [ -n "$pid" ] || continue
      if [ "$(started_at "$pid")" -lt "${moved:-0}" ]; then bad "Vite :$port démarré avant le dernier checkout de dematDashboard → le relancer"
      else ok "Vite :$port ($(readlink "/proc/$pid/cwd")) plus récent que le dernier checkout"; fi
    done
  fi
fi

printf '\n%d KO\n' "$ko"
[ "$ko" -eq 0 ]
