#!/usr/bin/env bash
# Run ApiTester headless on a tree, detached, and wait for it on its PID and its exit-code file.
# usage: apitester-run.sh start <tree> [flags of mise run headless...]
#          e.g. start ~/dev/wt-peren-topain-qa --test-set Demat --folder '[SCENARIO] A' --folder '[SCENARIO] B'
#          prints the run directory: pid, run.log, exit-code, then the reports.
#        apitester-run.sh wait <run directory> [budget in s=540]
#          blocks, looks every 5 s. DONE (exit 0) as soon as the run ended, DIED (exit 1) if it
#          died without an exit code, STILL_RUNNING (exit 75) once the budget is spent: call
#          wait again. 540 s stays under the 600 s of one tool call.
# Never wait with pgrep -f or a sleep loop: a pattern finds the shell that carries it. Abandon a
# run with kill -- -$(cat <dir>/pid): setsid makes that PID the process group of the whole run.
# APITESTER_DIR names another ApiTester checkout than ~/dev/zz-api-tester (a branch under test).
set -u
AT=${APITESTER_DIR:-$HOME/dev/zz-api-tester}
WS=Demat/Demat/PrinterTesterApp/ApiTester
cmd=${1:?start|wait}
shift

if [ "$cmd" = start ]; then
  T=$(realpath -e "${1:?tree}" 2>/dev/null) || { echo "arbre introuvable : $1" >&2; exit 2; }
  shift
  dir=${XDG_STATE_HOME:-$HOME/.local/state}/apitester/runs/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$dir" || exit 2
  args=(headless --report-dir "$dir")
  # The same three paths as the RUN line of check.sh post: on a worktree, mise.local.toml would
  # otherwise point the workspace at ~/dev/peren, and the collection does not follow it.
  if [ "$T" != "$(realpath -e "$HOME/dev/peren")" ]; then
    args+=(--workspace "$T/$WS" --postman-path "$T/postman/collections/Scenario de Test"
      --environment "$T/postman/environments/Local Demat.environment.yaml")
  fi
  args+=("$@")
  printf '%q ' cd "$AT" '&&' mise run "${args[@]}" > "$dir/command"
  # exit-code is written by rename, so wait never reads half a file.
  setsid nohup bash -c 'echo $$ > "$0/pid"; cd "$1" || exit 2; shift 2; mise run "$@" > "$0/run.log" 2>&1
    echo $? > "$0/exit-code.tmp"; mv "$0/exit-code.tmp" "$0/exit-code"' "$dir" "$AT" -- "${args[@]}" \
    < /dev/null > /dev/null 2>&1 &
  for _ in $(seq 50); do [ -s "$dir/pid" ] && break; sleep 0.1; done
  echo "$dir"
  exit 0
fi

if [ "$cmd" = wait ]; then
  dir=${1:?run directory}
  budget=${2:-540}
  [ -d "$dir" ] || { echo "dossier de run introuvable : $dir" >&2; exit 2; }
  started=$(date +%s)
  while :; do
    if [ -f "$dir/exit-code" ]; then
      trx=$dir/postman-report.trx
      if [ -f "$trx" ]; then trx_end=$(date -d "@$(stat -c %Y "$trx")" +%FT%T%:z); else trx_end=absent; fi
      echo "DONE exit=$(cat "$dir/exit-code") end=$(date -d "@$(stat -c %Y "$dir/exit-code")" +%FT%T%:z) trx=$trx_end"
      [ -f "$trx" ] && grep -o 'outcome="[A-Za-z]*"' "$trx" | sort | uniq -c
      [ "$(cat "$dir/exit-code")" = 0 ] || tail -n 15 "$dir/run.log"
      exit 0
    fi
    if ! kill -0 "$(cat "$dir/pid" 2>/dev/null)" 2>/dev/null; then
      [ -f "$dir/exit-code" ] && continue
      echo "DIED pid=$(cat "$dir/pid" 2>/dev/null) sans exit-code"
      tail -n 15 "$dir/run.log" 2>/dev/null
      exit 1
    fi
    if [ $(($(date +%s) - started)) -ge "$budget" ]; then
      echo "STILL_RUNNING après ${budget}s → relancer wait $dir"
      tail -n 1 "$dir/run.log" 2>/dev/null
      exit 75
    fi
    sleep 5
  done
fi

echo "commande inconnue : $cmd (start|wait)" >&2
exit 2
