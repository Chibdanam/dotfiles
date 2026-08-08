# Global instructions

## Bash tool usage

Never chain commands with `&&`, `||`, or `;` in a single Bash tool call. Use separate, parallel Bash tool calls instead so each command matches the allow rules individually.

## Git Workflow

- After completing a logical unit of work, commit with atomic, scoped commits (not one giant commit)
- Split into small and independant atomic commits. Keep concise description
- Preserve correct git authorship; verify `git config user.email` matches the repo's expected author before committing

@~/.claude/CLAUDE.local.md
