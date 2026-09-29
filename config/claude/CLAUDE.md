# Global instructions

## Bash tool usage

Never chain commands with `&&`, `||`, or `;` in a single Bash tool call. Use separate, parallel Bash tool calls instead so each command matches the allow rules individually.

## Git Workflow

- After completing a logical unit of work, commit with atomic, scoped commits (not one giant commit)
- Split into small and independant atomic commits. Keep concise description
- Never push to origin after committing unless told otherwise
- Branch names: `PR/#<WI>-Subject` is the root of an ADO work item. Every subdivision extends its parent's full name by one segment (`PR/#<WI>-Subject-Detail`, recursive) and merges `--no-ff` into that parent only, after a rebase on the parent's head. Full procedure and recipes: skill `gitflow`
- Worktrees: name the directory `wt-<project>-<feature-or-branch>` (e.g. `~/dev/wt-peren-odkconnect`). Never use the `zz-` prefix for a worktree: `zz-` marks internal, non-canonical projects hosted on our repos, not throwaway worktrees
- Merge feature branches with `--no-ff`. The merge commit body summarizes the branch in 3 to 5 lines: enough to know what it was about and why, not the details (those live in the feature commits). Keep the default subject (`Merge branch 'x' into y`). A merge lacking this body gets reworded (same tree, parents and dates), never squashed

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

@RTK.md
