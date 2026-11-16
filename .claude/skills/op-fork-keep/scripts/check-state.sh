#!/usr/bin/env bash
# State check of op-fork-keep and op-fork-new-wt: reads
# what a run left behind and prints the state it ended in.
#   forked   one new cmux pane, and one new fork process of the session in <dir>.
#            With <new-worktree>: that worktree exists, and the process runs in it or in <dir>.
#   nothing  no new pane and no new fork process
#   partial  anything else
# Usage: check-state.sh <dir> <session-id> <panes-before> <fork-pids-before> [<new-worktree>]
set -u
dir=$1 sid=$2 panes_before=$3 pids_before=$4 wt=${5:-}

panes_now=$(cmux list-panes 2>/dev/null | grep -c 'pane:')
new_pids=$(pgrep -f -- "--resume $sid --fork-session" | grep -vxF -f <(printf '%s\n' $pids_before) || true)
want=$(cd "$dir" && pwd -P)

in_dir=0
for p in $new_pids; do
  cwd=$(lsof -a -p "$p" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  # ponytail: with -w, which cwd the claude process reports is not tested, so both pass.
  { [ "$cwd" = "$want" ] || { [ -n "$wt" ] && [ "$cwd" = "$wt" ]; }; } && in_dir=$((in_dir + 1))
done
n_pids=$(printf '%s\n' $new_pids | grep -c .)
wt_ok=1
[ -n "$wt" ] && [ ! -d "$wt" ] && wt_ok=0

if [ "$panes_now" -eq $((panes_before + 1)) ] && [ "$n_pids" -eq 1 ] && [ "$in_dir" -eq 1 ] && [ "$wt_ok" -eq 1 ]; then
  echo forked
elif [ "$panes_now" -eq "$panes_before" ] && [ "$n_pids" -eq 0 ]; then
  echo nothing
else
  echo partial
fi
