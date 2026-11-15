#!/usr/bin/env bash
# Check one worktree-end lifecycle state against the invariants in
# plans/worktree-end/worktree-end.qnt.
#
# Usage: check-state.sh <fixture-dir>
#
# <fixture-dir> holds state.json: { phase, hasCommits, pushed, inSync, merged,
# removed, kept, onDefault, discardConfirmed }, the nine variables the model
# tracks.
#
# Trace replay is not available against an agent — an agent is not a
# deterministic function of state and action — so what transfers from the
# model is the invariant, checked against the state a real worktree-end
# invocation would be in at that point (phase reached, and what has and has
# not been called).
#
# Exits 0 when every rule holds, 1 when any fails, naming the rule.

set -uo pipefail

DIR="${1:-}"
STATE="$DIR/state.json"
if [[ -z "$DIR" || ! -f "$STATE" ]]; then
    echo "usage: check-state.sh <fixture-dir>" >&2
    exit 2
fi

fail=0
note() { echo "FAIL $1"; fail=1; }

removed=$(jq -r '.removed' "$STATE")
merged=$(jq -r '.merged' "$STATE")
pushed=$(jq -r '.pushed' "$STATE")
inSync=$(jq -r '.inSync' "$STATE")
hasCommits=$(jq -r '.hasCommits' "$STATE")
kept=$(jq -r '.kept' "$STATE")
onDefault=$(jq -r '.onDefault' "$STATE")
discardConfirmed=$(jq -r '.discardConfirmed' "$STATE")
phase=$(jq -r '.phase' "$STATE")

# Rule: removedImpliesPreserved. A worktree is never removed unless either its
# work is preserved somewhere — a remote branch verified merged into what it
# targeted on origin — there was never any work to preserve (no commits
# beyond its base) — or the user explicitly, typed-word confirmed discarding
# it on purpose. Merging a worktree always goes through a pushed branch + PR
# now; there is no local-merge route.
if [[ "$removed" == "true" ]] && [[ "$merged" != "true" ]] && [[ "$hasCommits" == "true" ]] && [[ "$discardConfirmed" != "true" ]]; then
    note "removedImpliesPreserved - removed=true, hasCommits=true, but merged=$merged, discardConfirmed=$discardConfirmed"
fi

# Rule: remoteRemovalRequiresPush. A confirmed merge never happens without
# having pushed first.
if [[ "$merged" == "true" ]] && [[ "$pushed" != "true" ]]; then
    note "remoteRemovalRequiresPush - merged=true but pushed=$pushed"
fi

# Rule: mergedRequiresInSync. A confirmed merge never happens against a local
# tip that had already drifted from what was pushed — new commits since the
# last push must be pushed again before a merge verdict means anything.
if [[ "$merged" == "true" ]] && [[ "$inSync" != "true" ]]; then
    note "mergedRequiresInSync - merged=true but inSync=$inSync"
fi

# Rule: onDefaultRequiresExited. The primary checkout is never reported as
# landed on the default branch before ExitWorktree actually fired.
if [[ "$onDefault" == "true" ]] && [[ "$kept" != "true" ]] && [[ "$removed" != "true" ]]; then
    note "onDefaultRequiresExited - onDefault=true but kept=$kept, removed=$removed"
fi

# Rule: blockedStaysInWorktree. A merge that GitHub blocks never leaves the
# worktree: no ExitWorktree call, keep or remove.
if [[ "$phase" == "merge_blocked" ]] && { [[ "$kept" == "true" ]] || [[ "$removed" == "true" ]]; }; then
    note "blockedStaysInWorktree - phase=merge_blocked but kept=$kept, removed=$removed"
fi

if (( fail == 0 )); then
    echo "ok  state in $DIR satisfies removedImpliesPreserved, remoteRemovalRequiresPush, mergedRequiresInSync, onDefaultRequiresExited, blockedStaysInWorktree"
fi
exit "$fail"
