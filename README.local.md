# Work machine layer

`professional` is `develop` plus the files below, and nothing else: a change that is not work-specific is made on `develop`, then this branch is rebased onto it. Flow and `.local` rules: [Branches](README.md#branches).

| File | What it adds |
|------|--------------|
| `config/claude/CLAUDE.local.md` | never push without being told, ADO branch names, worktree naming, `--no-ff` merge body |
| `config/claude/settings.local.json` | ask before `git push`, roslyn-ls and comment-diet plugins from the local work marketplace |
| `config/claude/skills/gitflow/` | branch, split and merge procedure of the peren ADO repos |
| `config/claude/skills/local-test-stack/` | proves the peren local test stack before a run |
| `config/claude/commands/brief.md` | `/brief`, the daily brief into the Obsidian note |
| `config/opencode/opencode.jsonc` | opencode on the DGX LiteLLM gateway; the key goes in `~/.config/dgx/token` |
| `config/lazygit/config.local.yml`, `config/zsh/lazygit.local.zsh` | colours for `PR/#…` and `Integration/` branches |
| `scripts/modules/tools.local.sh` | python, bruno and postman-cli through mise |
| `scripts/modules/dotnet.local.sh` | Azure Artifacts NuGet credential provider |
| `scripts/modules/dotfiles.local.sh` | deploys the opencode and lazygit files above |
