#!/bin/bash
# End-to-end test of the gitflow skill scripts in a throwaway repo:
# bash tests/run.sh [<skill dir>]
set -uo pipefail
SKILL=${1:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}
GF=$SKILL/scripts/gf
ROOT=$(mktemp -d)
export GIT_CONFIG_GLOBAL=$ROOT/gitconfig
git config --global user.name Me
git config --global user.email me@example.com
git config --global init.defaultBranch main
git config --global rebase.updateRefs true
git config --global rerere.enabled true

pass=0 fail=0
ok() { echo "PASS $*"; pass=$((pass + 1)); }
ko() { echo "FAIL $*"; fail=$((fail + 1)); }
expect() { local d=$1; shift; if "$@" > "$ROOT/out" 2>&1; then ok "$d"; else ko "$d"; sed 's/^/    /' "$ROOT/out"; fi; }
expect_fail() { local d=$1; shift; if "$@" > "$ROOT/out" 2>&1; then ko "$d (succeeded)"; sed 's/^/    /' "$ROOT/out"; else ok "$d"; sed 's/^/    | /' "$ROOT/out"; fi; }

git init -q --bare "$ROOT/remote.git"
git init -q "$ROOT/repo"
cd "$ROOT/repo"
git remote add origin "$ROOT/remote.git"
echo base > a.txt
git add a.txt
git commit -qm "Initial commit" -m "Body."
git push -q origin main

expect "hooks install" "$GF" hooks
expect "hooks install is idempotent" "$GF" hooks
git config --add gf.forbidden '\b[Ll]ots? ?[0-9]+'
git config --add gf.forbidden '\b(BACK|FRONT|E2E)-[0-9]+\b'

expect "start" "$GF" start 100 Feature main
[[ $(git branch --show-current) == "PR/#100-Feature" ]] && ok "on the ticket branch" || ko "on the ticket branch"
expect_fail "start refuses a hyphen" "$GF" start 101 Bad-Name main
expect_fail "start refuses a forbidden name" "$GF" start 102 Lot3Work main

echo one >> a.txt
git add a.txt
expect_fail "root commit without body refused" git commit -qm "Add one"
expect "root commit with body accepted" git commit -qm "Add one" -m "Because one is needed."
[[ $(git log -1 --format=%s) == "[#100-Feature] Add one" ]] && ok "root commit tagged" || ko "root commit tagged: $(git log -1 --format=%s)"
echo x >> a.txt
git add a.txt
expect_fail "forbidden word refused" git commit -qm "Finish lot 3" -m "Body."
git restore --staged a.txt
git checkout a.txt

expect "split" "$GF" split Detail
echo two > b.txt
git add b.txt
expect "leaf commit without body accepted" git commit -qm "wip two"
[[ $(git log -1 --format=%s) == "[#100-Feature-Detail] wip two" ]] && ok "leaf commit tagged" || ko "leaf commit tagged: $(git log -1 --format=%s)"
echo three >> b.txt
git commit -qam "wip three"

# The parent moves meanwhile
git switch -q 'PR/#100-Feature'
echo parent > c.txt
git add c.txt
git commit -qm "Add parent file" -m "The parent moved after the split."
git switch -q 'PR/#100-Feature-Detail'

printf 'Add the b file\n' > "$ROOT/msg-nobody"
expect_fail "land refuses a message without body" "$GF" land -F "$ROOT/msg-nobody"
[[ $(git rev-list --count 'PR/#100-Feature..PR/#100-Feature-Detail') == 2 ]] && ok "refused land changed nothing" || ko "refused land changed nothing"

printf '[#100-Feature-Detail] Add the b file\n\nThe b file holds two and three, needed by the next step.\n' > "$ROOT/msg"
tree_before=$(git rev-parse HEAD^{tree})
expect "land squashes into the parent" "$GF" land -F "$ROOT/msg"
[[ $(git branch --show-current) == "PR/#100-Feature" ]] && ok "now on the parent" || ko "now on the parent"
[[ $(git log -1 --format=%s) == "[#100-Feature] Add the b file" ]] && ok "squash commit retagged" || ko "squash commit retagged: $(git log -1 --format=%s)"
[[ $(git rev-list --count --merges main..HEAD) == 0 ]] && ok "no merge commit" || ko "no merge commit"
[[ $(git log -1 --format=%P | wc -w) == 1 ]] && ok "linear" || ko "linear"
git show-ref --verify --quiet 'refs/heads/PR/#100-Feature-Detail' && ko "leaf deleted" || ok "leaf deleted"
[[ -f c.txt && -f b.txt ]] && ok "both files present" || ko "both files present"

# Someone else's work: kept as is
"$GF" split Scenarios > /dev/null
echo s1 > s.txt
git add s.txt
GIT_AUTHOR_NAME=Jean GIT_AUTHOR_EMAIL=jean@example.com git commit -qm "Scenario one" -m "First scenario."
echo s2 >> s.txt
GIT_AUTHOR_NAME=Jean GIT_AUTHOR_EMAIL=jean@example.com git commit -qam "Scenario two" -m "Second scenario."
git switch -q 'PR/#100-Feature'
echo moved > d.txt
git add d.txt
git commit -qm "Move the parent again" -m "To force a rebase of the scenarios."
expect "land --keep from the parent" "$GF" land --keep 'PR/#100-Feature-Scenarios'
[[ $(git log -2 --format=%an | sort -u) == "Jean" ]] && ok "authorship kept" || ko "authorship kept"
git show-ref --verify --quiet 'refs/heads/PR/#100-Feature-Scenarios' && ok "kept branch still there" || ko "kept branch still there"

# Conflict during land
"$GF" split Conflict > /dev/null
echo leaf > a.txt
git commit -qam "Change a in leaf"
git switch -q 'PR/#100-Feature'
echo parent > a.txt
git commit -qam "Change a in parent" -m "Conflicting change."
git switch -q 'PR/#100-Feature-Conflict'
printf 'Resolve a\n\nBody line.\n' > "$ROOT/msg2"
expect_fail "land stops on conflict" "$GF" land -F "$ROOT/msg2"
git rebase --abort
git switch -q 'PR/#100-Feature'
git branch -D -q 'PR/#100-Feature-Conflict'

# Detached HEAD: the prepare-commit-msg hook stays silent
git switch -q --detach HEAD
echo det > e.txt
git add e.txt
git commit -qm "Detached commit" > "$ROOT/out" 2>&1
grep -q fatal "$ROOT/out" && ko "silent in detached HEAD" || ok "silent in detached HEAD"
[[ $(git log -1 --format=%s) == "Detached commit" ]] && ok "no tag in detached HEAD" || ko "no tag in detached HEAD"
git switch -q 'PR/#100-Feature'

# check
expect "check passes on the ticket branch" "$GF" check main
git switch -q -c 'PR/#100-Feature-Bad'
echo bad > f.txt
git add f.txt
git commit -qm "No body here"
expect_fail "check catches the leaf commit on a ticket" "$GF" check main 'PR/#100-Feature-Bad'
git switch -q 'PR/#100-Feature'
git branch -D -q 'PR/#100-Feature-Bad'

# pr-message
printf 'Line one of the summary.\nLine two.\nLine three.\n' > "$ROOT/body"
"$GF" pr-message 1781 "Handle zero-priced menu lines" "$ROOT/body" > "$ROOT/pr" 2>&1
[[ $(head -1 "$ROOT/pr") == "[#100-Feature] Merged PR 1781: Handle zero-priced menu lines" ]] && ok "pr-message header" || { ko "pr-message header"; cat "$ROOT/pr"; }

# rename NOWI -> work item, with a stacked branch and a branch on the tip
"$GF" start NOWI Thing main > /dev/null
echo n1 > n.txt
git add n.txt
GIT_COMMITTER_DATE="2020-01-01T10:00:00+02:00" GIT_AUTHOR_DATE="2020-01-01T09:00:00+02:00" git commit -qm "Thing one" -m "First."
echo n2 >> n.txt
git commit -qam "Thing two" -m "Second."
git branch tipcopy
git switch -q -c stacked
echo st > st.txt
git add st.txt
git commit -qm "Stacked" -m "On top."
git switch -q 'PR/#NOWI-Thing'
git tag backup-thing
old_tip=$(git rev-parse HEAD)
old_dates=$(git log --format='%ad %cd' --date=raw main..HEAD)
expect "rename NOWI to a work item" "$GF" rename 'PR/#NOWI-Thing' 'PR/#200-Thing' main
cat "$ROOT/out" | sed 's/^/    > /'
[[ $(git branch --show-current) == "PR/#200-Thing" ]] && ok "checked-out branch renamed" || ko "checked-out branch renamed"
[[ $(git log --format=%s main..HEAD | sort | tr '\n' '|') == "[#200-Thing] Thing one|[#200-Thing] Thing two|" ]] && ok "commits retagged" || ko "commits retagged: $(git log --format=%s main..HEAD)"
[[ $(git log --format='%ad %cd' --date=raw main..HEAD) == "$old_dates" ]] && ok "dates kept" || ko "dates kept"
[[ -z $(git status --porcelain) ]] && ok "worktree clean" || ko "worktree clean"
[[ $(git rev-parse tipcopy) == $(git rev-parse HEAD) ]] && ok "branch on the tip followed" || ko "branch on the tip followed"
[[ $(git rev-parse backup-thing) == "$old_tip" ]] && ok "tag kept as backup" || ko "tag kept as backup"
grep -q "git rebase --onto" "$ROOT/out" && ok "stacked branch reported" || ko "stacked branch reported"
grep -q WARNING "$ROOT/out" && ko "no unexpected ref change" || ok "no unexpected ref change"

# pre-push
git switch -q 'PR/#100-Feature'
expect "push a ticket branch" git push -q origin 'PR/#100-Feature'
git branch -q 'PR/#NOWI-Other' main
expect_fail "push a NOWI branch refused" git push -q origin 'PR/#NOWI-Other'
expect "push a NOWI branch with override" env GF_ALLOW_NOWI=1 git push -q origin 'PR/#NOWI-Other'
expect "delete a remote NOWI branch" git push -q origin --delete 'PR/#NOWI-Other'
git commit -q --amend -m "[#100-Feature] Change a in parent" -m "Amended body."
expect_fail "force push refused" git push -q --force origin 'PR/#100-Feature'
expect_fail "force-with-lease refused" git push -q --force-with-lease origin 'PR/#100-Feature'
expect "force push with override" env GF_ALLOW_FORCE=1 git push -q --force-with-lease origin 'PR/#100-Feature'

# Worktrees: a leaf or a parent checked out elsewhere is refused
"$GF" split Wt > /dev/null
echo wt > wt.txt
git add wt.txt
git commit -qm "Worktree leaf"
git switch -q 'PR/#100-Feature'
git worktree add -q "$ROOT/wt" 'PR/#100-Feature-Wt'
expect_fail "land refuses a leaf checked out elsewhere" "$GF" land -F "$ROOT/msg" 'PR/#100-Feature-Wt'
( cd "$ROOT/wt" && "$GF" land -F "$ROOT/msg" ) > "$ROOT/out" 2>&1 && ko "parent checked out elsewhere (from the leaf tree)" || ok "parent checked out elsewhere (from the leaf tree)"
git switch -q --detach
( cd "$ROOT/wt" && "$GF" land -F "$ROOT/msg" ) > "$ROOT/out" 2>&1 && ok "land from a linked worktree" || { ko "land from a linked worktree"; cat "$ROOT/out"; }
git worktree remove --force "$ROOT/wt"
git switch -q 'PR/#100-Feature'

# Rename an old-style branch with merges and sub-branch tags
"$GF" start 300 Old main > /dev/null
echo o > o.txt
git add o.txt
git commit -qm "Old root" -m "Body."
"$GF" split Sub > /dev/null
echo sub > sub.txt
git add sub.txt
git commit -qm "Sub work"
git switch -q 'PR/#300-Old'
git merge -q --no-ff 'PR/#300-Old-Sub' -m "Merge branch 'PR/#300-Old-Sub' into PR/#300-Old" -m "Summary."
merges_before=$(git rev-list --count --merges main..HEAD)
expect "rename a branch with merges" "$GF" rename 'PR/#300-Old' 'PR/#300-New' main
[[ $(git rev-list --count --merges main..HEAD) == "$merges_before" ]] && ok "merges kept" || ko "merges kept"
[[ $(git log --format=%s main..HEAD | grep -c '^\[#300-New') == 3 ]] && ok "root and sub tags retagged" || ko "root and sub tags: $(git log --format=%s main..HEAD)"
[[ $(git rev-parse 'PR/#300-Old-Sub') == $(git rev-parse HEAD^2) ]] && ok "merged sub-branch followed" || ko "merged sub-branch followed"

# Merges: body required on a branch, free in detached HEAD (throwaway QA merge)
git switch -q 'PR/#100-Feature'
"$GF" split Qa > /dev/null
echo qa > qa.txt
git add qa.txt
git commit -qm "Scenarios"
git switch -q --detach 'PR/#100-Feature'
expect "throwaway merge in detached HEAD" git merge -q --no-ff --no-edit 'PR/#100-Feature-Qa'
git switch -q -c merge-target 'PR/#100-Feature'
expect_fail "merge without body on a branch refused" git merge -q --no-ff --no-edit 'PR/#100-Feature-Qa'
git merge --abort 2> /dev/null
expect "merge with body on a branch accepted" git merge -q --no-ff 'PR/#100-Feature-Qa' -m "Merge branch 'PR/#100-Feature-Qa'" -m "Summary of the scenarios."
git switch -q 'PR/#100-Feature'

# Claude guard
guard() { jq -cn --arg c "$1" '{tool_input: {command: $c}}' | "$SKILL/scripts/claude-guard.sh"; }
for c in "az boards work-item create --title x" "az boards work-item relation add --id 1" "az repos pr create --title x" \
    "git push --force origin x" "rtk git -C ~/dev/peren push -f origin x" "git push origin +x" "git push --force-with-lease origin x" \
    "cd x; git push -uf origin y"; do
    [[ $(guard "$c") == *'"ask"'* ]] && ok "guard asks: $c" || ko "guard asks: $c"
done
for c in "az boards work-item show --id 1" "git push origin PR/#3541-MenuFix" "git push -u origin x" "git push --follow-tags origin x" "git status" "az repos pr list"; do
    [[ -z $(guard "$c") ]] && ok "guard lets through: $c" || ko "guard lets through: $c"
done

echo
echo "passed $pass, failed $fail"
rm -rf "$ROOT"
[[ $fail == 0 ]]
