# Work machine layer

Merged into the shared CLAUDE.md by the claude module: a `## ` heading repeated here replaces the shared section, a new one is appended. Nothing above the first `## ` is merged.

## Push

- Never push to origin after committing unless told otherwise

## Branches, worktrees and merges

- Branch names: `PR/#<WI>-Subject` is the root of an ADO work item. Every subdivision extends its parent's full name by one segment (`PR/#<WI>-Subject-Detail`, recursive) and merges `--no-ff` into that parent only, after a rebase on the parent's head. Full procedure and recipes: skill `gitflow`
- Worktrees: name the directory `wt-<project>-<feature-or-branch>`. On peren a team has two permanent worktrees and no more, `~/dev/wt-peren-topain-dev` and `~/dev/wt-peren-topain-qa`, reused from one work item to the next by switching branches; clones and `multica repo checkout` count too: skill `gitflow`. Never use the `zz-` prefix for a worktree: `zz-` marks internal, non-canonical projects hosted on our repos, not throwaway worktrees
- Merge feature branches with `--no-ff`. The merge commit body summarizes the branch in 3 to 5 lines: enough to know what it was about and why, not the details (those live in the feature commits). Keep the default subject (`Merge branch 'x' into y`). A merge lacking this body gets reworded (same tree, parents and dates), never squashed
