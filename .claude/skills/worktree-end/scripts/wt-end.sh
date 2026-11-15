#!/usr/bin/env bash
# Every git and gh step of the worktree-end skill. Plan: plans/worktree-end/.
# Each command prints one line, its first word the verdict. Git and gh output
# shows only on failure.
#
#   wt-end.sh status                    in the worktree: DIRTY (+ files), EMPTY,
#                                       UNPUSHED, DRIFT, PR_OPEN, PR_MERGED,
#                                       PR_CLOSED or PR_NONE
#   wt-end.sh push                      in the worktree: PUSHED pr=<url> | compare=<url>
#   wt-end.sh merge                     in the worktree: push, open the PR, squash-merge
#                                       it: MERGED, BLOCKED (exit 3) or FAILED
#   wt-end.sh force-remove <path> <br>  in the primary checkout: REMOVED or FAILED
#
# The whole script is one function, read before it runs: force-remove deletes
# the worktree this file may live in.

main() {
    set -uo pipefail
    fail() { echo "FAILED $*"; exit 1; }
    default_branch() { git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'; }
    has_upstream() { git rev-parse -q --verify '@{u}' >/dev/null 2>&1; }

    # Push the branch, with -u the first time. Sets $b and $d.
    push() {
        local out
        if has_upstream; then
            out=$(git push -q 2>&1) || fail "git push: $out"
        else
            out=$(git push -q -u origin "$b" 2>&1) || fail "git push: $out"
        fi
    }

    local cmd="${1:-}" b d
    if [[ "$cmd" != force-remove ]]; then
        b=$(git branch --show-current)
        d=$(default_branch)
        [[ -n "$b" ]] || fail "HEAD is detached"
        [[ -n "$d" ]] || fail "origin/HEAD is not set. Run: git remote set-head origin -a"
    fi

    case "$cmd" in
    status)
        local dirty n state url
        dirty=$(git status --porcelain)
        if [[ -n "$dirty" ]]; then
            echo "DIRTY"
            echo "$dirty"
            exit 0
        fi
        git fetch -q origin "$d" >/dev/null 2>&1
        n=$(git rev-list --count "origin/$d..HEAD")
        if (( n == 0 )); then
            echo "EMPTY default=$d"
        elif ! has_upstream; then
            echo "UNPUSHED commits=$n branch=$b default=$d"
        elif [[ "$(git rev-parse HEAD)" != "$(git rev-parse '@{u}')" ]]; then
            echo "DRIFT commits=$n branch=$b default=$d"
        else
            read -r state url < <(gh pr view "$b" --json state,url -q '.state + " " + .url' 2>/dev/null)
            echo "PR_${state:-NONE} branch=$b default=$d${url:+ url=$url}"
        fi
        ;;
    push)
        local url
        push
        if url=$(gh pr view "$b" --json url -q .url 2>/dev/null); then
            echo "PUSHED pr=$url"
        else
            url=$(git remote get-url origin | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##')
            echo "PUSHED compare=$url/compare/$d...$b?expand=1"
        fi
        ;;
    merge)
        local out err state mergeable status url
        push
        if ! gh pr view "$b" >/dev/null 2>&1; then
            out=$(gh pr create --base "$d" --head "$b" --fill 2>&1) || fail "gh pr create: $out"
        fi
        # No --delete-branch: it touches the local branch the worktree uses.
        err=$(gh pr merge "$b" --squash --match-head-commit "$(git rev-parse HEAD)" 2>&1)
        read -r state mergeable status url < <(gh pr view "$b" --json state,mergeable,mergeStateStatus,url \
            -q '[.state, .mergeable, .mergeStateStatus, .url] | join(" ")' 2>/dev/null)
        if [[ "$state" == MERGED ]]; then
            echo "MERGED url=$url"
            exit 0
        fi
        echo "BLOCKED mergeable=${mergeable:-?} status=${status:-?} url=${url:-?} gh: ${err%%$'\n'*}"
        exit 3
        ;;
    force-remove)
        local path="${2:-}" br="${3:-}" out
        [[ -n "$path" && -n "$br" ]] || fail "usage: wt-end.sh force-remove <path> <branch>"
        if ! out=$(git worktree remove --force "$path" 2>&1); then
            [[ "$out" == *locked* ]] || fail "git worktree remove: $out"
            git worktree unlock "$path" >/dev/null 2>&1
            out=$(git worktree remove --force "$path" 2>&1) || fail "git worktree remove: $out"
        fi
        # Only after the worktree is gone: deleting the branch first strands it.
        out=$(git branch -D "$br" 2>&1) || fail "worktree removed, but git branch -D: $out"
        echo "REMOVED"
        ;;
    *)
        fail "usage: wt-end.sh status|push|merge|force-remove <path> <branch>"
        ;;
    esac
}

main "$@"
