#!/usr/bin/env bash
# Test .claude/skills/worktree-end/scripts/wt-end.sh against real git repos: a
# bare origin, a clone, and a worktree of it. A stub `gh` on PATH holds the PR
# state in files, so no network is used.
#
# Usage: test-wt-end.sh [-v]     Exit 0 all good, 1 on failure.

set -uo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(CDPATH="" cd "$HERE/../../.." && pwd)"
S="$REPO/.claude/skills/worktree-end/scripts/wt-end.sh"

VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1
pass=0; fail=0

expect() { # expect <name> <pattern> <actual>
    if [[ "$3" == $2 ]]; then
        pass=$((pass+1)); (( VERBOSE )) && echo "ok      - $1"
    else
        fail=$((fail+1)); echo "not ok  - $1 (want $2, got: $3)"
    fi
    return 0
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GH_DIR="$WORK/gh"
mkdir -p "$WORK/bin" "$GH_DIR"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Stub gh. $GH_DIR/state: the PR state, absent = no PR. $GH_DIR/block: merge refused.
url=https://github.com/o/r/pull/1
case "$1 $2" in
"pr view")
    [[ -f "$GH_DIR/state" ]] || { echo "no pull requests found" >&2; exit 1; }
    st=$(cat "$GH_DIR/state")
    case "$*" in
    *mergeStateStatus*) [[ -f "$GH_DIR/block" ]] && echo "$st CONFLICTING DIRTY $url" || echo "$st MERGEABLE CLEAN $url" ;;
    *state,url*) echo "$st $url" ;;
    *url*) echo "$url" ;;
    esac ;;
"pr create") echo OPEN >"$GH_DIR/state"; echo "create $*" >>"$GH_DIR/log" ;;
"pr merge")
    echo "merge $*" >>"$GH_DIR/log"
    [[ -f "$GH_DIR/block" ]] && { echo "X Pull request o/r#1 is not mergeable: the merge commit cannot be cleanly created." >&2; exit 1; }
    echo MERGED >"$GH_DIR/state" ;;
esac
EOF
chmod +x "$WORK/bin/gh"
export PATH="$WORK/bin:$PATH"

q() { "$@" >/dev/null 2>&1; }
q git init -q --bare -b main "$WORK/origin.git"
q git clone -q "$WORK/origin.git" "$WORK/main"
q git -C "$WORK/main" commit -q --allow-empty -m init
q git -C "$WORK/main" push -q origin main
q git -C "$WORK/main" remote set-head origin main
q git -C "$WORK/main" worktree add -q -b feat "$WORK/wt"

wt() { (cd "$WORK/wt" && bash "$S" "$@" 2>&1); }

expect "no commits: EMPTY" "EMPTY default=main" "$(wt status)"

echo x >"$WORK/wt/f"
expect "uncommitted file: DIRTY" "DIRTY*f" "$(wt status)"

q git -C "$WORK/wt" add f
q git -C "$WORK/wt" commit -q -m f
expect "a commit, no upstream: UNPUSHED" "UNPUSHED commits=1 branch=feat default=main" "$(wt status)"

expect "push with no PR: compare URL" "PUSHED compare=*/compare/main...feat?expand=1" "$(wt push)"
expect "push sets the upstream" "origin/feat" "$(git -C "$WORK/wt" rev-parse --abbrev-ref '@{u}')"
expect "pushed, no PR: PR_NONE" "PR_NONE branch=feat default=main" "$(wt status)"

q git -C "$WORK/wt" commit -q --allow-empty -m more
expect "new commit after the push: DRIFT" "DRIFT commits=2*" "$(wt status)"

echo OPEN >"$GH_DIR/state"
expect "push with a PR: PR URL" "PUSHED pr=https://github.com/o/r/pull/1" "$(wt push)"
expect "in sync, PR open: PR_OPEN with URL" "PR_OPEN*url=https://github.com/o/r/pull/1" "$(wt status)"

touch "$GH_DIR/block"
out="$(wt merge)"; rc=$?
expect "blocked merge: BLOCKED with the reason" "BLOCKED mergeable=CONFLICTING status=DIRTY url=*gh: X Pull request*" "$out"
expect "blocked merge exits 3" "3" "$rc"
expect "blocked merge leaves the worktree" "yes" "$([[ -d "$WORK/wt" ]] && echo yes)"

rm "$GH_DIR/block"
expect "merge: MERGED" "MERGED url=*" "$(wt merge)"
expect "merge never passes --delete-branch" "" "$(grep -- --delete-branch "$GH_DIR/log")"
expect "merge pins the head commit" "*--match-head-commit $(git -C "$WORK/wt" rev-parse HEAD)*" "$(tail -1 "$GH_DIR/log")"
expect "merged: PR_MERGED" "PR_MERGED*" "$(wt status)"

# Merge now with no PR yet opens one first.
rm -f "$GH_DIR/state" "$GH_DIR/log"
q git -C "$WORK/wt" commit -q --allow-empty -m again
expect "merge with no PR: MERGED" "MERGED url=*" "$(wt merge)"
expect "merge with no PR: creates it" "create pr create --base main --head feat --fill" "$(head -1 "$GH_DIR/log")"

expect "force-remove: REMOVED" "REMOVED" "$(cd "$WORK/main" && bash "$S" force-remove "$WORK/wt" feat 2>&1)"
expect "force-remove deletes the worktree" "no" "$([[ -d "$WORK/wt" ]] && echo yes || echo no)"
expect "force-remove deletes the branch" "" "$(git -C "$WORK/main" branch --list feat)"

q git -C "$WORK/main" worktree add -q -b locked "$WORK/wt2"
q git -C "$WORK/main" worktree lock "$WORK/wt2"
expect "force-remove of a locked worktree: REMOVED" "REMOVED" "$(cd "$WORK/main" && bash "$S" force-remove "$WORK/wt2" locked 2>&1)"

expect "force-remove of a missing worktree keeps the branch" "FAILED git worktree remove:*" \
    "$(q git -C "$WORK/main" branch keepme; cd "$WORK/main" && bash "$S" force-remove "$WORK/nope" keepme 2>&1)"
expect "the branch is still there" "*keepme" "$(git -C "$WORK/main" branch --list keepme)"

echo "pass $pass, fail $fail"
(( fail == 0 ))
