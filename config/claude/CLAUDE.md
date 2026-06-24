# Global instructions

## Tone and Behavior

- Never use the '—' character.
- Push back and challenge me when I'm wrong, might be wrong, or am missing a better approach, standard, or convention.
- Ask questions if my intent is unclear, ask rather than guess. Use the "Ask user" tool.

## Bash tool usage

Never chain commands with `&&`, `||`, or `;` in a single Bash tool call. Use separate, parallel Bash tool calls instead so each command matches the allow rules individually.

## Git Workflow

- After completing a logical unit of work, commit with atomic, scoped commits (not one giant commit)
- Split into small, independant and atomic commits. Keep concise description
- Never push to origin after committing unless told otherwise