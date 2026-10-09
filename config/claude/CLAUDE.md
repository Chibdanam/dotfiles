# Global instructions

## Git Workflow

- After completing a logical unit of work, commit with atomic, scoped commits (not one giant commit)
- Split into small and independant atomic commits. Keep concise description
- Preserve correct git authorship; verify `git config user.email` matches the repo's expected author before committing

## Dotfiles

`~/dev/dotfiles` versions this machine's config; `install.sh` deploys it to the live paths (mapping in `scripts/modules/*.sh`). This file is itself `config/claude/CLAUDE.md` there.

- When you change a live config (`~/.claude/`, `~/.config/{zsh,nvim,tmux,herdr,mise,lazygit,rtk}`, `~/.gitconfig`, `~/.gitignore`, `~/.local/bin` helpers, crontab…) and the change is meant to last, make the same change in `~/dev/dotfiles` in the same pass and commit it there. A config with no counterpart yet gets one, plus the install step that deploys it
- Commit what suits every machine on `develop`, then rebase the machine's layer branch (`personal`, `professional`) onto it. A layer only adds what is specific to its context, as `.local` files next to the shared ones, never as an edit of a shared file (README, section Branches)
- Edit both sides by hand. Never propagate with `install.sh`: it overwrites whole files and would erase live-only content not yet backported
- If the live file and its dotfiles copy already differ before your change, report the drift instead of copying one over the other
- Never version secrets (they go to `~/.config/zsh/.secrets.zsh` or `~/.gitconfig.local`), machine-specific paths or versions, or state that tools write themselves (caches, logs, generated sections). Throwaway tweaks stay live only; ask when unsure a change is worth keeping
