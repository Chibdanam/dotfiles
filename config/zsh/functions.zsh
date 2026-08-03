# Set git to use personal account in current repository
# Safe to run multiple times - will simply update the config
git-personal() {
	local git_root
	git_root=$(git rev-parse --show-toplevel 2>/dev/null)
	
	if [[ -z "$git_root" ]]; then
		echo "Error: Not in a git repository"
		return 1
	fi
	
	git config --local user.name "Chibdanam"
	git config --local user.email "chibdanam@gmail.com"
	
	echo "Git personal account configured for: $(basename "$git_root")"
	echo "  Name:  Chibdanam"
	echo "  Email: chibdanam@gmail.com" 
}

# Shorter alias for git-personal
alias gsp='git-personal'

# Redirect a command's `git config --global` writes to ~/.gitconfig.local, which
# install.sh never overwrites.  e.g. git-local gh auth setup-git
# Never export GIT_CONFIG_GLOBAL: it replaces ~/.gitconfig instead of adding to it.
git-local() { GIT_CONFIG_GLOBAL="$HOME/.gitconfig.local" "$@"; }
