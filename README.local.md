# Work machine layer

`professional` is `develop` plus the files below, and nothing else: a change that is not work-specific is made on `develop`, then this branch is rebased onto it. Flow and `.local` rules: [Branches](README.md#branches).

| File | What it adds |
|------|--------------|
| `config/claude/CLAUDE.local.md` | never push without being told, ADO ticket branches and local leaves, worktree naming, PR and `--no-ff` merge messages |
| `config/claude/settings.local.json` | ask before `git push`, roslyn-ls and comment-diet plugins from the local work marketplace |
| `config/claude/skills/gitflow/references/peren.md` | peren side of the shared gitflow skill: forbidden vocabulary, PRs in French, hooks, where the Topain worktrees are described |
| `config/claude/skills/local-test-stack/` | proves the peren local test stack before a run |
| `config/claude/commands/brief.md` | `/brief`, the daily brief into the Obsidian note |
| `config/opencode/opencode.jsonc` | opencode on the DGX LiteLLM gateway; the key goes in `~/.config/dgx/token` |
| `config/lazygit/config.local.yml`, `config/zsh/lazygit.local.zsh` | colours for `PR/#…` and `Integration/` branches |
| `scripts/modules/tools.local.sh` | python, bruno and postman-cli through mise |
| `scripts/modules/dotnet.local.sh` | Azure Artifacts NuGet credential provider |
| `scripts/modules/dotfiles.local.sh` | deploys the opencode and lazygit files above |
