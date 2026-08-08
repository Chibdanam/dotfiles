# Set git to use the personal account in the current repository.
# The identity is machine-local: [personal] name/email in ~/.gitconfig.local
# (see config/git/gitconfig.local.example). Safe to run multiple times.
git-personal() {
	local git_root name email
	git_root=$(git rev-parse --show-toplevel 2>/dev/null)

	if [[ -z "$git_root" ]]; then
		echo "Error: Not in a git repository"
		return 1
	fi

	name=$(git config --file "$HOME/.gitconfig.local" personal.name 2>/dev/null)
	email=$(git config --file "$HOME/.gitconfig.local" personal.email 2>/dev/null)

	if [[ -z "$name" || -z "$email" ]]; then
		echo "Error: personal identity not configured"
		echo "Add it to ~/.gitconfig.local:"
		echo "  [personal]"
		echo "  	name = Your Name"
		echo "  	email = you@example.com"
		return 1
	fi

	git config --local user.name "$name"
	git config --local user.email "$email"

	echo "Git personal account configured for: $(basename "$git_root")"
	echo "  Name:  $name"
	echo "  Email: $email"
}

# Shorter alias for git-personal
alias gsp='git-personal'

# Redirect a command's `git config --global` writes to ~/.gitconfig.local, which
# install.sh never overwrites.  e.g. git-local gh auth setup-git
# Never export GIT_CONFIG_GLOBAL: it replaces ~/.gitconfig instead of adding to it.
git-local() { GIT_CONFIG_GLOBAL="$HOME/.gitconfig.local" "$@"; }
