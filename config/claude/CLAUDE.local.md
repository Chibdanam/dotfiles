# Work machine layer

Merged into the shared CLAUDE.md by the claude module: a `## ` heading repeated here replaces the shared section, a new one is appended. Nothing above the first `## ` is merged.

## Push

- Never push to origin after committing unless told otherwise

## Branches, worktrees and merges

- Branch names: `PR/#<WI>-Subject` is the one linear branch of an ADO work item, the only one that reaches origin, every commit with a body. Work is split into local leaves that extend its name (`PR/#<WI>-Subject-Detail`), never pushed, each brought back as one squashed commit by `gf land`. Full procedure and the `gf` script: skill `gitflow`
- Worktrees: name the directory `wt-<project>-<feature-or-branch>`. Never use the `zz-` prefix for a worktree: `zz-` marks internal, non-canonical projects hosted on our repos, not throwaway worktrees
- Merges: a ticket branch enters its integration branch through its PR, completed as a merge (no fast-forward) whose message is rewritten in English with a 3 to 5 line body (`gf pr-message`). Elsewhere, merge feature branches with `--no-ff`, keep the default subject (`Merge branch 'x' into y`) and add a 3 to 5 line body: enough to know what it was about and why, not the details. A merge lacking this body gets reworded (same tree, parents and dates), never squashed
