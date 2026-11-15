#!/usr/bin/env bash
# Rebase the current git worktree branch onto the latest origin/main.
#
# Exit codes mirror model.qnt's `outcome` values exactly, so a test can assert
# `sync.sh`'s exit code against the model's classification for the same
# {isWorktree, isClean, fetchOk, conflict} state:
#
#   0  NOT_WORKTREE   not running inside a linked worktree — no-op
#   1  DIRTY          working tree not clean — stopped before touching anything
#   2  FETCH_FAILED   `git fetch origin main` failed — no rebase attempted
#   3  CONFLICT       rebase left a conflict — left in progress for manual fix
#   4  SUCCESS        rebased cleanly onto origin/main (or already up to date)
#
# Never touches the local `main` ref (no `main:main` refspec, no `branch -f
# main`) — `main` is checked out in another worktree, and updating it from here
# would hit git's checkout-lock error. Never auto-stashes, auto-aborts, or
# forces anything — every stop point leaves the tree exactly as found.

set -uo pipefail

NOT_WORKTREE=0
DIRTY=1
FETCH_FAILED=2
CONFLICT=3
SUCCESS=4

# Step 0 of using-git-worktrees: GIT_DIR != GIT_COMMON_DIR means a linked
# worktree, except inside a submodule, which has the same property.
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON=$(git rev-parse --git-common-dir 2>/dev/null)
if [[ -z "$GIT_DIR" || -z "$GIT_COMMON" ]]; then
    echo "not a git repository" >&2
    exit "$NOT_WORKTREE"
fi

SUPERPROJECT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
if [[ -n "$SUPERPROJECT" ]]; then
    echo "inside a submodule, not a linked worktree — worktree-sync does not apply here" >&2
    exit "$NOT_WORKTREE"
fi

if [[ "$(cd "$GIT_DIR" && pwd -P)" == "$(cd "$GIT_COMMON" && pwd -P)" ]]; then
    echo "not inside a linked worktree — worktree-sync only runs there" >&2
    exit "$NOT_WORKTREE"
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "working tree is dirty — commit or stash by hand first, worktree-sync will not do it for you" >&2
    exit "$DIRTY"
fi

if ! FETCH_OUTPUT=$(git fetch origin main 2>&1); then
    echo "git fetch origin main failed:" >&2
    echo "$FETCH_OUTPUT" >&2
    exit "$FETCH_FAILED"
fi

BEFORE=$(git rev-parse HEAD)

if git rebase origin/main; then
    AFTER=$(git rev-parse HEAD)
    if [[ "$BEFORE" == "$AFTER" ]]; then
        echo "already up to date with origin/main"
    else
        echo "rebased onto origin/main:"
        git log --oneline "${BEFORE}..${AFTER}"
    fi
    exit "$SUCCESS"
fi

REBASE_MERGE=$(git rev-parse --git-path rebase-merge 2>/dev/null)
REBASE_APPLY=$(git rev-parse --git-path rebase-apply 2>/dev/null)
if [[ -d "$REBASE_MERGE" || -d "$REBASE_APPLY" ]]; then
    echo "rebase onto origin/main hit a conflict — left in progress for manual resolution:" >&2
    git status --porcelain | awk '$1 ~ /^U/ || $1 == "AA" || $1 == "DD" {print "  " $0}' >&2
    exit "$CONFLICT"
fi

echo "git rebase origin/main failed for a reason other than a merge conflict — left in progress for manual resolution" >&2
exit "$CONFLICT"
