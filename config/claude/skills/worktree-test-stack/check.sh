#!/usr/bin/env bash
# Prove a peren worktree can be tested: ignored local files present, apps running FROM it, fresh binaries, Cosmos alive.
# usage: check.sh <worktree> [main-tree=~/dev/peren]
set -u
W=${1:?worktree path}; M=${2:-$HOME/dev/peren}
ok=0; ko=0
say() { printf '  %-6s %s\n' "$1" "$2"; [ "$1" = OK ] && ok=$((ok+1)) || ko=$((ko+1)); }

echo "== fichiers ignorés (copiés depuis $M s'ils manquent)"
for f in mise.toml CoreWebApi/appsettings.shared.Local.json compose.wsl.yml certs/aspnet-dev.pfx certs/aspnet-dev.pem certs/aspnet-dev.key \
  Demat/Demat/PrinterTesterApp/ApiTester/Config/collection.environment.json \
  Demat/Demat/PrinterTesterApp/ApiTester/Config/collection.settings.json \
  Demat/Demat/PrinterTesterApp/ApiTester/Config/collection.global.json \
  Demat/Demat/PrinterTesterApp/ApiTester/Config/collection.local.json; do
  if [ ! -f "$W/$f" ] && [ -f "$M/$f" ]; then mkdir -p "$(dirname "$W/$f")"; cp "$M/$f" "$W/$f"; say COPIE "$f (manquait)"; ok=$((ok-1));
  elif [ -f "$W/$f" ] && [ -f "$M/$f" ] && ! cmp -s "$M/$f" "$W/$f"; then say OK "$f (diffère de l'arbre principal : jetons ou réglages rafraîchis d'un côté, on garde celui du worktree)";
  elif [ -f "$W/$f" ]; then say OK "$f"; else say KO "$f absent des deux arbres"; fi
done

echo "== process"
for app in CoreWebApi ArchiveWebApi DematProcessor InvoiceGenerationWebJobs; do
  pid=$(pgrep -f "bin/Debug/net8.0/$app\$" | head -1)
  if [ -z "$pid" ]; then say KO "$app ne tourne pas"; continue; fi
  cwd=$(readlink "/proc/$pid/cwd"); case "$cwd" in "$W"*) say OK "$app pid=$pid depuis le worktree";; *) say KO "$app pid=$pid tourne depuis $cwd";; esac
  dll="$W/$app/bin/Debug/net8.0/$app.dll"; last=$(git -C "$W" log -1 --format=%ct -- '*.cs' '*.csproj')
  if [ -f "$dll" ] && [ "$(stat -c %Y "$dll")" -ge "$last" ]; then say OK "$app.dll postérieur au dernier commit de code"; else say KO "$app.dll plus ancien que le dernier commit de code (ou absent)"; fi
done
for app in CoreWebApi ArchiveWebApi; do
  log=$HOME/logs/$app/latest.log
  if [ -f "$log" ] && grep -q "Content root path: $W" "$log" && grep -q "Now listening on" "$log"; then say OK "$app: content root = worktree, écoute"; else say KO "$app: content root ≠ worktree ou pas encore à l'écoute ($log)"; fi
done

echo "== cosmos"
if docker inspect peren-cosmos >/dev/null 2>&1; then
  docker inspect peren-cosmos --format '  info   status={{.State.Status}} restarts={{.RestartCount}} started={{.State.StartedAt}}'
  started=$(date -d "$(docker inspect peren-cosmos --format '{{.State.StartedAt}}')" +%s)
  core=$(pgrep -f 'bin/Debug/net8.0/ArchiveWebApi$' | head -1)
  if [ -n "$core" ] && [ "$started" -gt "$(stat -c %Y /proc/$core 2>/dev/null || echo 0)" ]; then say KO "l'émulateur a redémarré APRÈS ArchiveWebApi : base Archive probablement perdue → mise r cosmos:init puis restart archive demat invoice"; else say OK "émulateur plus ancien que les apps"; fi
else say KO "conteneur peren-cosmos absent"; fi

echo "== apitester"
echo "  APITESTER_HOME=$W/Demat/Demat/PrinterTesterApp/ApiTester dotnet run --project src/ApiTester -- --print-paths   # depuis ~/dev/zz-api-tester"
printf '\n%d OK, %d KO\n' "$ok" "$ko"; [ "$ko" -eq 0 ]
