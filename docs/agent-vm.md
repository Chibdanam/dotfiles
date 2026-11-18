# Agent VM checklist

An agent VM (`vm-agent-01`, `vm-agent-02`) is an extension of the workstation: the same shell, tools
and Claude setup, on a runtime of its own, so that work delegated there does not slow the workstation
down. The dotfiles make its environment ready; what comes after is set up by hand and listed here so
that the next VM gets the same.

## 1. The environment: the dotfiles

On the VM, with `sudo` enabled:

```bash
git clone --branch professional https://github.com/Chibdanam/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh --yes all
```

`--yes` asks nothing and creates the keys without passphrase, so that the VM keeps working after a
reboot with nobody there. Without it, the install asks for the passphrases and, the first time, for
the git identity (the same as the workstation's, character for character; with `--yes`, pass it as
`DOTFILES_GIT_NAME` and `DOTFILES_GIT_EMAIL`).

The install can be run again at any time. It ends up with:

- three SSH keys (`id_ed25519` for GitHub, `id_rsa_azdo` for Azure DevOps, which takes RSA only,
  `id_ed25519_signing` for commits) and their `~/.ssh/config` entries;
- git with its identity, commits and tags signed, `allowed_signers` filled;
- zsh launched from `~/.bashrc`, since `chsh` fails for a directory account;
- Docker Engine with compose, the account in the `docker` group (it applies at the next login, and
  a herdr server already running has to be restarted to get it);
- the tools, the Azure CLI with its azure-devops extension, Claude Code and its configuration.

It closes with the "Action items" still open, and stops listing one once it is done:

1. The keys to register: `id_rsa_azdo.pub` in Azure DevOps (User settings, SSH public keys),
   `id_ed25519.pub` and `id_ed25519_signing.pub` in GitHub (Settings, SSH and GPG keys, as
   authentication and signing keys).
2. The accounts to log in: `az login --use-device-code`, `gh auth login` (then `./install.sh git`
   for its credential helpers), `claude auth login`.

## 2. By hand, once the environment is ready

Not the dotfiles' job: done once per VM, as needed.

- **Secrets**: `~/.config/zsh/.secrets.zsh` (mode 600, from `config/zsh/secrets.zsh.example`:
  `FIGMA_TOKEN`, `LITELLM_API_KEY`) and `~/.config/dgx/token`, seeded empty by the install.
- **herdr machine**, from the workstation: `herdr machine add vm-agent-NN`. herdr refuses a
  machine on another version than its own: the install puts the latest release on the VM, so
  `herdr update` on the workstation first if it is behind.
- **Repositories**, once the Azure DevOps key is registered:

  ```bash
  git clone git@ssh.dev.azure.com:v3/conferosas/peren/AIMarketplace ~/dev/AIMarketplace
  git clone git@ssh.dev.azure.com:v3/conferosas/peren/peren ~/dev/peren
  git clone git@ssh.dev.azure.com:v3/conferosas/peren/DevLens ~/dev/DevLens
  ```

- **Claude plugins**: in `~/dev/AIMarketplace`, the branch that holds the `peren` plugin
  (`PR/#NOWI-PerenPlugin` until it reaches main), then
  `claude plugin install roslyn-ls@local comment-diet@local peren@local -s user`. The marketplace
  path is already in `~/.claude/settings.json`.
- **Machine note**: `~/CLAUDE.local.md`, read by Claude in every session under the home: that it
  runs on an agent VM, what the VM is and how the user reaches it. Copied from another VM, with the
  two VM names changed.
- **gitflow in peren**: `~/.claude/skills/gitflow/scripts/gf hooks`, and the `gf.forbidden` patterns
  listed by the skill `peren:gitflow-reference`.

Not looked at yet: the peren local test stack in Docker (SQL Server, Azurite, Cosmos emulator, the
ignored files of `~/dev/peren`), `apitester`, `~/dev/zz-daily-cron` (`/brief` points at a path that does not exist on
a VM). PowerShell 7.7.0 had no `powershell.linux-x64` package on NuGet on 2026-11-18: the install
falls back on the release before it, and returns to the latest once it installs.

## State of the VMs

| VM | Install | Keys registered | Logins | Secrets | herdr machine | Repositories |
|----|---------|-----------------|--------|---------|---------------|--------------|
| `vm-agent-01` | 2026-11-17 | yes | yes | no | yes | dotfiles only |
| `vm-agent-02` | 2026-11-18 | yes | yes | no | yes | dotfiles only |

`vm-agent-01` was first installed before the ssh and git modules set up keys and signing (Ubuntu
24.04, account `mcma@odk.pro` from Entra ID, home `/home/mcma@odk.pro`); its `id_ed25519` dates from
that run.
