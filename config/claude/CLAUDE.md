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

## Dotfiles

`~/dev/dotfiles` versions this machine's config; `install.sh` deploys it to the live paths (mapping in `scripts/modules/*.sh`). This file is itself `config/claude/CLAUDE.md` there.

- When you change a live config (`~/.claude/`, `~/.config/{zsh,nvim,tmux,herdr,mise,lazygit,rtk}`, `~/.gitconfig`, `~/.gitignore`, `~/.local/bin` helpers, crontab…) and the change is meant to last, make the same change in `~/dev/dotfiles` in the same pass and commit it there. A config with no counterpart yet gets one, plus the install step that deploys it
- Edit both sides by hand. Never propagate with `install.sh`: it overwrites whole files and would erase live-only content not yet backported
- If the live file and its dotfiles copy already differ before your change, report the drift instead of copying one over the other
- Never version secrets (they go to `~/.config/zsh/.secrets.zsh` or `~/.gitconfig.local`), machine-specific paths or versions, or state that tools write themselves (caches, logs, generated sections). Throwaway tweaks stay live only; ask when unsure a change is worth keeping

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->

@RTK.md
