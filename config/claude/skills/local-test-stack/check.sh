#!/usr/bin/env bash
# Prove the local peren stack runs the code of one tree before a test run reads it.
# usage: check.sh pre|post [tree=~/dev/peren] [main tree=~/dev/peren]
#   post  read only, the stack is up: every app runs from the tree on its current build, Cosmos
#         is intact, ApiTester points at the tree. All OK = run the tests, nothing to restart.
#   pre   the stack is down (mise r stop): ignored files copied into a worktree, launch
#         profiles, Cosmos up, its database created if missing. Then mise r start, then post.
set -u
phase=${1:?pre|post}
T=$(realpath -e "${2:-$HOME/dev/peren}" 2>/dev/null) || { echo "arbre introuvable : ${2:-}" >&2; exit 2; }
M=$(realpath -e "${3:-$HOME/dev/peren}" 2>/dev/null) || { echo "arbre introuvable : ${3:-}" >&2; exit 2; }
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

# What an app is built from: the directory of its project and of every ProjectReference,
# recursively, the files they pull in with Compile Include, and the local config every app reads.
closure() {
  local todo=("$T/$1/$1.csproj") seen=" " p ref
  while [ ${#todo[@]} -gt 0 ]; do
    p=$(realpath -m "${todo[0]}"); todo=("${todo[@]:1}")
    case $seen in *" $p "*) continue ;; esac
    case $p in "$T"/*) ;; *) continue ;; esac   # references to a vendor checkout outside the tree
    seen="$seen$p "
    dirname "$p"
    while read -r ref; do
      case $ref in *.csproj) todo+=("$(dirname "$p")/${ref//\\//}") ;; *) realpath -m "$(dirname "$p")/${ref//\\//}" ;; esac
    done < <(grep -oE '(ProjectReference|Compile) Include="[^"*]*"' "$p" 2>/dev/null | sed 's/.*Include="//; s/"$//')
  done
  echo "$T/CoreWebApi/appsettings.shared.Local.json"
}

cosmos_expired() { docker logs --tail 300 peren-cosmos 2>&1 | grep -q 'evaluation period has expired'; }
cosmos_failed() {
  if cosmos_expired; then bad "licence de l'émulateur expirée → env -C $M docker compose -f compose.wsl.yml pull cosmos, puis mise r cosmos:restart"
  else bad "Cosmos ne répond pas ($1) → env -C $M mise r cosmos:restart"; fi
}

# pre: cosmos-init is idempotent and never touches a document; "created" means it was missing.
cosmos_init() {
  local script=$T/Scripts/cosmos-init.py out
  [ -f "$script" ] || script=$M/Scripts/cosmos-init.py
  if ! out=$(timeout 300 python3 "$script" 2>&1) || grep -q FAILED <<<"$out"; then cosmos_failed "$(tail -1 <<<"$out")"
  elif grep -q ' created' <<<"$out"; then info "base Archive recréée : elle avait disparu, les reçus locaux sont perdus (le dire)"
  else ok "Cosmos : base Archive et conteneurs présents"; fi
}

# post: one signed GET on the containers of the database, the same key and endpoint the apps use.
cosmos_read() {
  python3 - "$T/CoreWebApi" <<'PY'
import base64, hashlib, hmac, json, ssl, sys, urllib.error, urllib.parse, urllib.request
from email.utils import formatdate
from pathlib import Path
core = Path(sys.argv[1])
s = json.loads((core / "appsettings.shared.json").read_text(encoding="utf-8-sig"))["CosmosDbSettings"]
local = core / "appsettings.shared.Local.json"
if local.exists():
    s.update(json.loads(local.read_text(encoding="utf-8-sig")).get("CosmosDbSettings", {}))
link, date = f"dbs/{s['DatabaseName']}", formatdate(usegmt=True)
mac = hmac.new(base64.b64decode(s["PrimaryKey"]), f"get\ncolls\n{link}\n{date.lower()}\n\n".encode(), hashlib.sha256)
auth = urllib.parse.quote(f"type=master&ver=1.0&sig={base64.b64encode(mac.digest()).decode()}", safe="")
req = urllib.request.Request(f"{s['EndpointUri'].rstrip('/')}/{link}/colls",
                             headers={"Authorization": auth, "x-ms-date": date, "x-ms-version": "2018-12-31"})
tls = ssl.create_default_context(); tls.check_hostname = False; tls.verify_mode = ssl.CERT_NONE
try:
    with urllib.request.urlopen(req, timeout=15, context=tls) as response:
        count = len(json.load(response).get("DocumentCollections", []))
    print(f"{count} conteneur(s)")
    sys.exit(0 if count else 3)
except urllib.error.HTTPError as error:
    print(f"HTTP {error.code}")
    sys.exit(3 if error.code == 404 else 2)
except Exception as error:
    print(error)
    sys.exit(2)
PY
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
  if [ "$state" = "running healthy" ]; then cosmos_init
  elif cosmos_expired; then cosmos_failed "$state"
  else bad "peren-cosmos : ${state:-absent} → env -C $M mise r infra:up, attendre healthy (~3 min)"; fi
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

  # The apps' Cosmos clients do not reliably survive a restart or a new database: any of the
  # three below means relaunching the four apps after the fix.
  started=$(date -d "$(docker inspect -f '{{.State.StartedAt}}' peren-cosmos 2>/dev/null || echo 1970-01-01)" +%s)
  [ "$started" -gt "$oldest" ] && bad "peren-cosmos a redémarré après les apps → relancer les 4 apps"
  docker logs --since "$oldest" peren-cosmos 2>&1 | grep -qE 'Capturing a dump|fatal error' \
    && bad "peren-cosmos a planté sur place depuis le démarrage des apps (Docker dit healthy) → env -C $M mise r cosmos:restart"
  out=$(cosmos_read); rc=$?
  case $rc in
    0) ok "Cosmos : base Archive, $out" ;;
    3) bad "Cosmos : base Archive absente ou vide ($out) → env -C $T mise r cosmos:init, reçus locaux perdus (le dire)" ;;
    *) cosmos_failed "$out" ;;
  esac

  if [ -d "$AT" ]; then
    info "ApiTester dev : $(git -C "$AT" branch --show-current) $(git -C "$AT" rev-parse --short HEAD), $(git -C "$AT" status --porcelain | wc -l) fichier(s) modifié(s)"
    (cd "$AT" && mise run status 2>/dev/null) | sed 's/^ */        /'
    args=()
    if [ "$T" != "$M" ]; then
      args=(-workspace "$T/$WS" -postmanPath "$T/postman/collections/Scenario de Test"
        -postmanEnvironment "$T/postman/environments/Local Demat.environment.yaml")
    fi
    paths=$(cd "$AT" && mise exec -- dotnet run --project src/ApiTester --no-build -- --print-paths "${args[@]}" 2>/dev/null | grep -E '^[a-zA-Z]+=')
    root=$(sed -n 's/^root=//p' <<<"$paths"); collection=$(sed -n 's/^collection=//p' <<<"$paths")
    case $root in "$T"/*) ok "workspace : $root" ;; *) bad "workspace : ${root:-non résolu} ≠ $T" ;; esac
    if ! grep -q '^collection=' <<<"$paths"; then info "collection non affichée : ce build de l'ApiTester précède feature/headless-workspace"
    else case $collection in
      "") bad "aucune collection sélectionnée dans les réglages de l'ApiTester" ;;
      "$T"/*) ok "collection : $collection" ;;
      *) bad "collection : $collection ≠ $T" ;;
    esac; fi
    dirty=$(git -C "$T" status --porcelain -- "$WS/Results" | wc -l)
    [ "$dirty" -eq 0 ] && ok "Results/ propre" || warn "Results/ : $dirty capture(s) déjà modifiée(s), le diff du run les mélangera"
    echo "  RUN   bash ~/.claude/skills/local-test-stack/apitester-run.sh start '$T' --test-set Demat --folder '<[SCENARIO] …>'"
    echo "        bash ~/.claude/skills/local-test-stack/apitester-run.sh wait <dossier affiché>   (jusqu'à DONE)"
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
