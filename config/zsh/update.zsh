# update-all - one pass over every updater this machine needs.
#
# Steps never abort each other: a failing updater is recorded and the run keeps
# going, so one broken tool can't silently skip the rest. A missing binary
# counts as skipped. The summary at the end is the part worth reading.

_update_all_apt() {
	sudo apt-get update -qq || return
	# --with-new-pkgs mirrors what `apt upgrade` does: pull in new dependencies
	# rather than hold a package back. apt-get is the CLI that's stable for
	# scripts; plain `apt` warns about exactly this use. confdef and confold:
	# dpkg keeps a locally modified config file without asking, so a run with
	# no terminal never waits on a question. The optional sudo rule of
	# local-manager (plugins/updates/README.md) names exactly these command
	# lines: change both together.
	sudo apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
		--with-new-pkgs upgrade -y
}

_update_all_mise() {
	mise self-update --yes --quiet || return
	# -C pins this to the global config. Without it, `mise up` also bumps the
	# tools of whatever project directory you happened to launch from.
	mise -C "$HOME" up
}

_update_all_zinit() {
	zinit self-update || return
	zinit update --all
}

_update_all_step() {
	local label=$1 bin=$2
	shift 2

	if ! command -v "$bin" > /dev/null 2>&1; then
		_ua_skipped+=("$label")
		return 0
	fi

	print -P "\n%F{blue}==>%f $label"
	"$@"
	local rc=$?

	if (( rc == 0 )); then
		_ua_ok+=("$label")
	else
		_ua_failed+=("$label (exit $rc)")
	fi
}

update-all() {
	emulate -L zsh

	local -a _ua_ok _ua_failed _ua_skipped

	# local-manager's panel runs update-all with no terminal. A sudo rule set up
	# by hand (its plugins/updates/README.md) lets apt and snap run there
	# without a password. Without the rule, a terminal primes the sudo
	# timestamp up front, or the password
	# prompt would land minutes into the run, whenever the apt or snap step is
	# reached, and block there unnoticed. Without either, apt and snap fail
	# fast and the rest goes on.
	if ! sudo -n -l /usr/bin/apt-get update -qq > /dev/null 2>&1 && [[ -t 0 ]] && ! sudo -v; then
		print -u2 "update-all: sudo unavailable, aborting"
		return 1
	fi

	_update_all_step "apt packages"   apt-get   _update_all_apt
	_update_all_step "mise + tools"   mise      _update_all_mise
	_update_all_step "claude code"    claude    claude update
	_update_all_step "herdr"          herdr     herdr update
	_update_all_step "codegraph"      codegraph codegraph upgrade
	_update_all_step "opencode"       opencode  opencode upgrade
	_update_all_step "rust toolchain" rustup    rustup update
	_update_all_step "snap packages"  snap      sudo snap refresh
	_update_all_step "zsh plugins"    zinit     _update_all_zinit
	_update_all_step "nvim plugins"   nvim      nvim --headless '+lua vim.pack.update(nil, { force = true })' +qa

	print -P "\n%F{blue}==>%f summary"
	(( $#_ua_ok ))      && print -P "  %F{green}ok%f       ${(j:, :)_ua_ok}"
	(( $#_ua_skipped )) && print -P "  %F{yellow}skipped%f  ${(j:, :)_ua_skipped}"
	(( $#_ua_failed ))  && print -P "  %F{red}failed%f   ${(j:, :)_ua_failed}"

	(( $#_ua_failed == 0 ))
}
