# Shared by gf and the git hooks of the gitflow skill. Sourced, never run.

GF_TRAILERS='^(Co-authored-by|Signed-off-by|Reviewed-by|Helped-by|Topic|Branch):'
GF_AUTOSQUASH='^(\[[^]]*\] )*(fixup|squash|amend)!'

gf_die() {
    printf 'gf: %s\n' "$*" >&2
    exit 1
}

# Commit tag of a branch: its name after the last slash, as the
# prepare-commit-msg hook writes it.
gf_tag() {
    printf '%s' "${1##*/}"
}

gf_branch_exists() {
    git show-ref --verify --quiet "refs/heads/$1"
}

# A ticket branch has one segment after the work item: PR/#<id>-<Name>.
gf_is_root() {
    [[ $1 =~ ^PR/#[^-/]+-[^-]+$ ]]
}

# Parent of a leaf: its name without the last -Segment, the first one that
# exists as a local branch. Prints nothing for a root.
gf_parent() {
    local name=$1
    while [[ ${name##*/} == *-*-* ]]; do
        name=${name%-*}
        if gf_branch_exists "$name"; then
            printf '%s' "$name"
            return 0
        fi
    done
    return 1
}

# Path of the worktree that has the branch checked out, empty if none.
gf_worktree_of() {
    git worktree list --porcelain | awk -v ref="branch refs/heads/$1" '
        /^worktree / { path = substr($0, 10) }
        $0 == ref { print path; exit }'
}

# Message as git will store it: comments and the scissors part removed.
gf_clean_message() {
    git stripspace --strip-comments < "$1"
}

# Prints one line per violation, returns 1 if any. A body is a paragraph
# after the subject that is not only trailers.
gf_check_message() {
    local file=$1 require_body=$2
    local msg subject body pattern status=0
    msg=$(gf_clean_message "$file")
    subject=$(printf '%s\n' "$msg" | sed -n '1p')
    body=$(printf '%s\n' "$msg" | sed '1,/^$/d' | grep -Ev "$GF_TRAILERS" | grep -v '^[[:space:]]*$' || true)

    if [[ -z $subject ]]; then
        echo "empty message"
        return 1
    fi
    if [[ $require_body == 1 && -z $body ]] && ! [[ $subject =~ $GF_AUTOSQUASH ]]; then
        echo "no body: say what the change does and why, after a blank line"
        status=1
    fi
    if [[ $require_body == 1 ]] && [[ $(printf '%s\n' "$msg" | sed -n '2p') != "" ]]; then
        echo "the subject must be followed by a blank line"
        status=1
    fi
    while IFS= read -r pattern; do
        [[ -z $pattern ]] && continue
        if printf '%s\n' "$msg" | grep -Eq -- "$pattern"; then
            echo "forbidden pattern /$pattern/: $(printf '%s\n' "$msg" | grep -Eo -- "$pattern" | head -1)"
            status=1
        fi
    done < <(git config --get-all gf.forbidden || true)
    return $status
}

# Same patterns against a branch name.
gf_check_name() {
    local name=$1 pattern status=0
    while IFS= read -r pattern; do
        [[ -z $pattern ]] && continue
        if printf '%s\n' "$name" | grep -Eq -- "$pattern"; then
            echo "forbidden pattern /$pattern/ in branch name $name"
            status=1
        fi
    done < <(git config --get-all gf.forbidden || true)
    return $status
}
