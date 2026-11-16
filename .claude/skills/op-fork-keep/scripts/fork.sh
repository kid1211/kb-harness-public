#!/usr/bin/env bash
# op-fork-keep and op-fork-new-wt: fork the Claude session that
# runs this script into a new cmux split pane, then check the run.
#   fork.sh            in the same directory, worktree or not
#   fork.sh --new-wt   in a new worktree from origin/main, which the fork owns
# Prints one line on success. On a failure, what failed and the command to run by hand.
set -u
here=$(cd "$(dirname "$0")" && pwd)
skill=op-fork-keep new_wt=
[ "${1:-}" = --new-wt ] && { skill=op-fork-new-wt; new_wt=1; }

# the facts. The directory is the session's current one, worktree or not.
dir=$(pwd -P)
sid=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$sid" ] || { echo "$skill: no session ID (CLAUDE_CODE_SESSION_ID is not set). Nothing opened."; exit 1; }

# the new worktree goes into the main checkout's .claude/worktrees/, with
# the first free name of fork-<8 chars of the session ID>, -2, -3, ...
wt_args= wt_path= wt_branch=
if [ -n "$new_wt" ]; then
  common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
    || { echo "$skill: $dir is not in a git repo. Nothing opened."; exit 1; }
  main=$(cd "$common/.." && pwd -P)
  base="fork-${sid:0:8}" name=$base n=1
  while [ -e "$main/.claude/worktrees/$name" ] || git -C "$dir" show-ref -q --verify "refs/heads/worktree-$name"; do
    n=$((n + 1)); name="$base-$n"
  done
  wt_args=" -w $name" wt_path="$main/.claude/worktrees/$name" wt_branch="refs/heads/worktree-$name"
fi
by_hand="cd $(printf %q "$dir") && claude --resume $sid --fork-session$wt_args"

if [ -z "${CMUX_SURFACE_ID:-}" ] || ! command -v cmux >/dev/null; then
  echo "$skill: this session is not inside cmux. Nothing opened. Run by hand: $by_hand"
  exit 1
fi

# What the checks compare against.
panes_before=$(cmux list-panes 2>/dev/null | grep -c 'pane:')
pids_before=$(pgrep -f -- "--resume $sid --fork-session" | tr '\n' ' ')
wt_before=$(git -C "$dir" worktree list --porcelain 2>/dev/null | grep '^worktree ')
br_before=$(git -C "$dir" branch --format='%(refname)' 2>/dev/null)

state() { "$here/check-state.sh" "$dir" "$sid" "$panes_before" "$pids_before" "$wt_path"; }
check() { "$here/check-output.sh" "$1" "$(state)" "$dir" "$wt_before" "$br_before" "$wt_path" "$wt_branch"; }

fail() { # $1: what failed. Close the pane this run opened, then check that nothing is left.
  [ -n "${surface:-}" ] && cmux close-surface --surface "$surface" >/dev/null 2>&1
  # the name was free before this run, so a worktree or branch there was made by this run's claude -w
  if [ -n "$wt_path" ]; then
    [ -e "$wt_path" ] && git -C "$dir" worktree remove --force "$wt_path" >/dev/null 2>&1
    git -C "$dir" branch -D "${wt_branch#refs/heads/}" >/dev/null 2>&1
  fi
  echo "$skill: $1. Run by hand: $by_hand"
  check nothing
  exit 1
}

surface=$(cmux new-split right --focus false 2>&1 | grep -o 'surface:[0-9]*' | head -1)
[ -n "$surface" ] || fail "cmux new-split failed"
# never trust the folder the pane starts in. The command cd's first.
cmux send --surface "$surface" "$by_hand"'\n' >/dev/null 2>&1 || fail "cmux send failed"

# The fork process takes a moment to start, and to make its worktree.
for _ in $(seq 20); do
  [ "$(state)" = forked ] && break
  sleep 0.5
done
[ "$(state)" = forked ] || fail "claude did not start the fork"

check forked || exit 1
if [ -n "$new_wt" ]; then
  echo "$skill: forked into $surface, in the new worktree $wt_path from origin/main"
else
  echo "$skill: forked into $surface, in $dir"
fi
