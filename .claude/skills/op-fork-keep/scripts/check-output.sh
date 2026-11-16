#!/usr/bin/env bash
# Output check of op-fork-keep and op-fork-new-wt: the state
# the run reached is the one it meant to reach, and the worktrees and branches
# changed only as they should. op-fork-keep makes none. A forked
# op-fork-new-wt makes exactly <new-worktree> and <new-branch>.
# Prints nothing and exits 0 on a pass. Prints each failure and exits 1 otherwise.
# Usage: check-output.sh <expected-state> <actual-state> <dir> <worktrees-before> <branches-before> [<new-worktree> <new-branch>]
set -u
expected=$1 actual=$2 dir=$3 wt_before=$4 br_before=$5 wt=${6:-} br=${7:-}
fail=0

wt_want=$wt_before br_want=$br_before
if [ -n "$wt" ] && [ "$expected" = forked ]; then
  wt_want=$(printf '%s\nworktree %s\n' "$wt_before" "$wt")
  br_want=$(printf '%s\n%s\n' "$br_before" "$br")
fi
sorted() { printf '%s\n' "$1" | grep . | sort; }

[ "$actual" = "$expected" ] || { echo "check: state is '$actual', expected '$expected'"; fail=1; }
[ "$(sorted "$(git -C "$dir" worktree list --porcelain | grep '^worktree ')")" = "$(sorted "$wt_want")" ] \
  || { echo "check: the list of worktrees is not the one expected"; fail=1; }
[ "$(sorted "$(git -C "$dir" branch --format='%(refname)')")" = "$(sorted "$br_want")" ] \
  || { echo "check: the list of branches is not the one expected"; fail=1; }
exit $fail
