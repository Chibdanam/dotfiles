# Work machine layer

`professional` is `develop` plus the files below, and nothing else: a change that is not work-specific is made on `develop`, then this branch is rebased onto it. Flow and `.local` rules: [Branches](README.md#branches).

| File | What it adds |
|------|--------------|
| `config/claude/CLAUDE.local.md` | never push without being told, ADO ticket branches and local leaves, worktree naming, PR and `--no-ff` merge messages |
| `config/claude/settings.local.json` | ask before `git push`, roslyn-ls, comment-diet and peren plugins from the local work marketplace (`~/dev/AIMarketplace`, cloned by hand) |
| `config/claude/commands/brief.md` | `/brief`, the daily brief into the Obsidian note |
| `config/opencode/opencode.jsonc` | opencode on the DGX LiteLLM gateway; the key goes in `~/.config/dgx/token` |
| `config/lazygit/config.local.yml`, `config/zsh/lazygit.local.zsh` | colours for `PR/#…` and `Integration/` branches |
| `config/mise/front.sh`, `config/mise/conf.d/front.toml` | `front:*` mise tasks to serve, stop and update the npm fronts |
| `scripts/modules/tools.local.sh` | python and postman-cli through mise, the Azure CLI with its azure-devops extension and its default organization and project, a reminder when Azure is not logged in |
| `scripts/modules/dotnet.local.sh` | .NET 8 and 10 SDKs next to the latest, Azure Artifacts NuGet credential provider |
| `scripts/modules/ssh.local.sh` | RSA key and `~/.ssh/config` entry for Azure DevOps |
| `scripts/modules/dotfiles.local.sh` | deploys the opencode, lazygit and mise files above |
| `docs/agent-vm.md` | checklist of an agent VM: the install, then what is done by hand once the environment is ready |
