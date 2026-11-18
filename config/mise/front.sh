#!/bin/bash
# The front:* tasks of conf.d/front.toml: a front served by npm, the same from
# a terminal as from local-manager's panel (its ADR 0016), in the current
# folder, checkout or worktree.
#
#   front.sh start SCRIPT   deps, then npm run SCRIPT in its own session,
#                           output in ~/logs/<service>/log-<datetime>.log
#   front.sh stop SCRIPT    stops that session, and the group holding the port
#                           its output announces
#   front.sh sync           git pull --ff-only on the tracked branch, then deps
#   front.sh deps [-f]      npm install when package.json or package-lock.json
#                           is newer than the last one
#
# <service> is the script's prefix (retailer for retailer:serve-devlocal),
# else the repository's name: a folder of ~/logs, which logx reads. The
# session is noted in ~/.local/state/front/<service>.pgid: its group, the
# folder it serves, its log and its script.
set -euo pipefail

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/front

# The repository's name, the same from any of its worktrees.
repo_name() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || { basename "$PWD"; return; }
  basename "$(dirname "$common")"
}

service_of() {
  case $1 in
    *:*) printf '%s\n' "${1%%:*}" ;;
    *) repo_name ;;
  esac
}

# npm, with the folder's node: its own mise config when it has one, else the
# major version of its .nvmrc. A worktree lacks the gitignored
# mise.local.toml of its checkout, and the global node may be outside the
# engines that .npmrc enforces.
npm_command() {
  NPM=(npm)
  if [ -e .nvmrc ] && [ ! -e mise.toml ] && [ ! -e mise.local.toml ] && [ ! -e .mise.toml ]; then
    local major
    major=$(tr -d 'v \r\n' < .nvmrc)
    major=${major%%.*}
    if [ -n "$major" ]; then NPM=(mise x "node@$major" -- npm); fi
  fi
}

# One install or pull at a time per repository. The same lock as the tasks of
# dematDashboard's mise.local.toml.
lock() {
  local dir
  dir=$(git rev-parse --git-common-dir 2>/dev/null) || dir=.
  exec 9> "$dir/mise-sync.lock"
  flock 9
}

# node_modules/.front-deps is touched after each install; before the first,
# npm's own node_modules/.package-lock.json stands for it. A pull or a branch
# switch that changes a lockfile rewrites it, so makes it newer.
deps_needed() {
  [ -d node_modules ] || return 0
  local ref=node_modules/.front-deps
  [ -e "$ref" ] || ref=node_modules/.package-lock.json
  [ -e "$ref" ] || return 0
  [ package.json -nt "$ref" ] || [ package-lock.json -nt "$ref" ]
}

deps() {
  if [ "${1:-}" != -f ] && ! deps_needed; then
    echo "deps: up to date"
    return 0
  fi
  npm_command
  echo "deps: ${NPM[*]} install"
  "${NPM[@]}" install
  # Without dependencies, npm makes no node_modules.
  mkdir -p node_modules
  touch node_modules/.front-deps
}

sync() {
  lock
  local branch upstream
  if branch=$(git symbolic-ref --short -q HEAD) && upstream=$(git rev-parse --abbrev-ref -q '@{u}' 2>/dev/null); then
    echo "pull: $branch <- $upstream"
    git pull --ff-only
  else
    echo "pull: no branch, or no upstream: skipped"
  fi
  deps
}

# A group that still has a process.
alive() {
  pgrep -g "$1" > /dev/null
}

start() {
  local script=${1:-} service file dir log pid
  [ -n "$script" ] || { echo "front:start: a script of package.json is needed" >&2; exit 2; }
  service=$(service_of "$script")
  file=$state_dir/$service.pgid
  if [ -e "$file" ] && alive "$(cut -f1 "$file")"; then
    if [ "$(cut -f4 "$file")" != "$script" ]; then
      echo "front: $service already serves $(cut -f4 "$file"), from $(cut -f2 "$file")" >&2
      exit 1
    fi
    echo "front: $script already runs, from $(cut -f2 "$file")"
    return 0
  fi
  # In a subshell: the lock goes before the server starts.
  (lock; deps)
  dir=$HOME/logs/$service
  log=$dir/log-$(date +%Y-%m-%d_%H-%M-%S).log
  mkdir -p "$dir" "$state_dir"
  npm_command
  # Its own session, stdin closed: it outlives this task and its terminal.
  # Not a group leader here, so setsid does not fork: $! leads the session.
  setsid "${NPM[@]}" run "$script" < /dev/null > "$log" 2>&1 &
  pid=$!
  ln -sfn "$log" "$dir/latest.log"
  printf '%s\t%s\t%s\t%s\n' "$pid" "$PWD" "$log" "$script" > "$file"
  echo "front: $script started from $PWD, output in $log"
}

# The port of the last « Local: » URL Vite wrote, colours removed.
served_port() {
  [ -e "$1" ] || return 0
  sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$1" | grep -o 'Local: *http[^ ]*' | tail -n 1 \
    | sed -E 's#^.*://[^/]*:([0-9]+).*$#\1#' | grep -E '^[0-9]+$' || true
}

# The process listening on the port, from ss.
port_holder() {
  ss -Htlnp "sport = :$1" | grep -o 'pid=[0-9]*' | head -n 1 | cut -d= -f2 || true
}

stop() {
  local script=${1:-} service file log port holder group groups=() left mine=false
  [ -n "$script" ] || { echo "front:stop: a script of package.json is needed" >&2; exit 2; }
  service=$(service_of "$script")
  file=$state_dir/$service.pgid
  log=$HOME/logs/$service/latest.log
  if [ -e "$file" ]; then
    if [ "$(cut -f4 "$file")" = "$script" ]; then
      mine=true
      groups+=("$(cut -f1 "$file")")
      log=$(cut -f3 "$file")
    else
      # The service's latest output is another script's.
      log=
    fi
  fi
  # turbo starts Vite in a session of its own: the group holding the port.
  port=$(served_port "$log")
  if [ -n "$port" ]; then
    holder=$(port_holder "$port")
    if [ -n "$holder" ]; then groups+=("$(ps -o pgid= -p "$holder" | tr -d ' ')"); fi
  fi
  left=()
  for group in "${groups[@]}"; do
    if [ "$group" -gt 1 ] && alive "$group"; then left+=("$group"); fi
  done
  if [ ${#left[@]} -eq 0 ]; then
    if $mine; then rm -f "$file"; fi
    echo "front: $script does not run"
    return 0
  fi
  for group in "${left[@]}"; do kill -TERM -- "-$group" 2> /dev/null || true; done
  for _ in $(seq 50); do
    local any=false
    for group in "${left[@]}"; do if alive "$group"; then any=true; fi; done
    $any || break
    sleep 0.1
  done
  for group in "${left[@]}"; do kill -KILL -- "-$group" 2> /dev/null || true; done
  if $mine; then rm -f "$file"; fi
  echo "front: $script stopped"
}

case ${1:-} in
  start) start "${2:-}" ;;
  stop) stop "${2:-}" ;;
  sync) sync ;;
  deps) lock; deps "${2:-}" ;;
  *) echo "usage: front.sh start|stop SCRIPT, or sync, or deps [-f]" >&2; exit 2 ;;
esac
