#!/usr/bin/env bash
# Integration tests for scripts/sync.sh against ../model.qnt.
#
# Every fixture's {isWorktree, isClean, fetchOk, conflict} -> outcome mapping
# comes from the model, not from this file. Each witness_state call below runs
# `quint verify` on a deliberately-false invariant (`outcome != <bucket>`, the
# same technique the model's own NEGATIVE CONTROL uses) and hands the
# counterexample's ITF trace to trace-to-fixture.py, which writes the plain
# boolean tuple it names. This script only supplies the git plumbing that
# *realizes* a given tuple as an actual repository — the mapping from booleans
# to git commands is not something Quint can generate, so it is hand-written
# and reviewed, per spec-implement's Step 1. No .itf.json is stored; every
# trace is regenerated on this run.
#
# Usage: test-worktree-sync.sh [-v]     Exit 0 all good, 1 on failure.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
SYNC="$HERE/scripts/sync.sh"
MODEL="$HERE/model.qnt"
QUINT="$REPO_ROOT/node_modules/.bin/quint"
TO_FIXTURE="$HERE/tests/trace-to-fixture.py"

[[ -x "$SYNC" ]] || { echo "cannot find sync.sh at $SYNC" >&2; exit 2; }
[[ -x "$QUINT" ]] || { echo "cannot find pinned quint at $QUINT — run 'npm install' first" >&2; exit 2; }

VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

pass=0; fail=0

check() { # check <name> <expected> <actual>
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass=$((pass+1)); (( VERBOSE )) && echo "ok       - $name"
    else
        fail=$((fail+1)); echo "not ok   - $name (expected $expected, got $actual)"
    fi
}

check_absent() { # check_absent <name> <needle> <haystack>
    local name="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        fail=$((fail+1)); echo "not ok   - $name (found forbidden: $needle)"
    else
        pass=$((pass+1)); (( VERBOSE )) && echo "ok       - $name"
    fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# witness_state <invariant> <label> -> writes $WORK/<label>/state-0/config.env,
# prints its path. The model chooses the state; this is just plumbing to get it
# onto disk as a fixture, same shape as research-artifacts/tests' trace-to-fixture
# use.
witness_state() {
    local inv="$1" label="$2" apalache_out="$WORK/apalache-$label"
    mkdir -p "$apalache_out"
    ( cd "$apalache_out" && "$QUINT" verify "$MODEL" --invariant="$inv" --max-steps=0 ) >/dev/null 2>&1
    local cex
    cex="$(find "$apalache_out" -name 'violation1.itf.json' 2>/dev/null | sort | tail -1)"
    if [[ -z "$cex" || ! -s "$cex" ]]; then
        echo "quint verify --invariant=$inv produced no counterexample" >&2
        return 1
    fi
    python3 "$TO_FIXTURE" "$cex" "$WORK/fixture-$label" >/dev/null
    echo "$WORK/fixture-$label/state-0/config.env"
}

git_quiet() { git "$@" >/dev/null 2>&1; }

# --- fixture builders -------------------------------------------------------
# Each builds a real origin + checkout realizing one outcome bucket, prints the
# directory sync.sh should be run from. Driven by $ISWORKTREE/$ISCLEAN/
# $FETCHOK/$CONFLICT, read from the model's own config.env — not hardcoded here.

fixture_not_worktree() {
    local base="$WORK/repo-not-worktree"; mkdir -p "$base"
    ( cd "$base" && git_quiet init -b main && git_quiet config user.email t@t && \
      git_quiet config user.name t && echo seed > f && git_quiet add f && \
      git_quiet commit -m seed )
    echo "$base"
}

fixture_dirty() {
    local origin="$WORK/dirty-origin.git" local_="$WORK/dirty-local" wt="$WORK/dirty-wt"
    git_quiet init --bare -b main "$origin"
    git_quiet clone "$origin" "$local_"
    ( cd "$local_" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo seed > f && git_quiet add f && git_quiet commit -m seed && git_quiet push origin main )
    ( cd "$local_" && git_quiet worktree add "$wt" -b feature )
    echo "dirty, uncommitted" >> "$wt/f"
    echo "$wt"
}

fixture_fetch_failed() {
    local origin="$WORK/fetch-origin.git" local_="$WORK/fetch-local" wt="$WORK/fetch-wt"
    git_quiet init --bare -b main "$origin"
    git_quiet clone "$origin" "$local_"
    ( cd "$local_" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo seed > f && git_quiet add f && git_quiet commit -m seed && git_quiet push origin main )
    ( cd "$local_" && git_quiet worktree add "$wt" -b feature )
    ( cd "$wt" && git_quiet remote set-url origin "/nonexistent/$(basename "$(mktemp -u)")" )
    echo "$wt"
}

fixture_conflict() {
    local origin="$WORK/conflict-origin.git" local_="$WORK/conflict-local" wt="$WORK/conflict-wt" scratch="$WORK/conflict-scratch"
    git_quiet init --bare -b main "$origin"
    git_quiet clone "$origin" "$local_"
    ( cd "$local_" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo seed > f && git_quiet add f && git_quiet commit -m seed && git_quiet push origin main )
    ( cd "$local_" && git_quiet worktree add "$wt" -b feature )
    ( cd "$wt" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo "workdir change" > f && git_quiet commit -am "workdir change" )
    git_quiet clone "$origin" "$scratch"
    ( cd "$scratch" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo "origin change" > f && git_quiet commit -am "origin change" && git_quiet push origin main )
    echo "$wt"
}

fixture_success() {
    local origin="$WORK/success-origin.git" local_="$WORK/success-local" wt="$WORK/success-wt" scratch="$WORK/success-scratch"
    git_quiet init --bare -b main "$origin"
    git_quiet clone "$origin" "$local_"
    ( cd "$local_" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo seed > f && git_quiet add f && git_quiet commit -m seed && git_quiet push origin main )
    ( cd "$local_" && git_quiet worktree add "$wt" -b feature )
    ( cd "$wt" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo "workdir file" > g && git_quiet add g && git_quiet commit -m "workdir change" )
    git_quiet clone "$origin" "$scratch"
    ( cd "$scratch" && git_quiet config user.email t@t && git_quiet config user.name t && \
      echo "origin file" > h && git_quiet add h && git_quiet commit -m "origin change" && git_quiet push origin main )
    echo "$wt"
}

# --- run one bucket ---------------------------------------------------------
# run_bucket <label> <invariant> <fixture-fn> <expected-w> <expected-c> <expected-f> <expected-x>
run_bucket() {
    local label="$1" inv="$2" fn="$3" ew="$4" ec="$5" ef="$6" ex="$7"
    local cfg
    cfg=$(witness_state "$inv" "$label") || { fail=$((fail+1)); echo "not ok   - $label (witness extraction failed)"; return; }

    # shellcheck source=/dev/null
    ISWORKTREE=""; ISCLEAN=""; FETCHOK=""; CONFLICT=""; OUTCOME=""
    source "$cfg"
    check "$label: model witness isWorktree" "$ew" "$ISWORKTREE"
    check "$label: model witness isClean" "$ec" "$ISCLEAN"
    check "$label: model witness fetchOk" "$ef" "$FETCHOK"
    check "$label: model witness conflict" "$ex" "$CONFLICT"

    local dir; dir="$("$fn")"
    local actual_exit
    ( cd "$dir" && bash "$SYNC" ) >/dev/null 2>&1
    actual_exit=$?
    check "$label: sync.sh exit code matches model outcome" "$OUTCOME" "$actual_exit"
}

echo "=== outcome buckets, fixtures and expected outcomes from the model's own witnesses ==="
run_bucket "NOT_WORKTREE" witnessNotWorktree  fixture_not_worktree  0 0 0 1
run_bucket "DIRTY"        witnessDirty        fixture_dirty         1 0 0 1
run_bucket "FETCH_FAILED" witnessFetchFailed  fixture_fetch_failed  1 1 0 1
run_bucket "CONFLICT"     witnessConflict     fixture_conflict      1 1 1 1
run_bucket "SUCCESS"      neverSucceeds       fixture_success       1 1 1 0

echo
echo "=== file predicates against scripts/sync.sh (single-file rows the gate skipped the model for) ==="
# Comment-stripped: the header comment explains what these rules forbid by
# name, which would otherwise trip its own check.
SRC="$(grep -vE '^\s*#' "$SYNC")"
check_absent "never fetches into local main"          "main:main"                 "$SRC"
check_absent "never force-updates local main via branch -f" "branch -f main"      "$SRC"
check_absent "never force-updates local main via update-ref" "update-ref refs/heads/main" "$SRC"
check_absent "never auto-stashes"                      "git stash"                 "$SRC"
check_absent "never auto-aborts the rebase"            "rebase --abort"            "$SRC"
check_absent "never forces anything"                   " --force"                  "$SRC"
check_absent "never forces anything (short flag)"      " -f "                      "$SRC"

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
