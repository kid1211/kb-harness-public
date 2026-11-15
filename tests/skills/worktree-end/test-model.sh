#!/usr/bin/env bash
# Test check-state.sh against states the model checker actually
# explored.
#
# The arrangement, and the reason for it: fixtures are regenerated from
# plans/worktree-end/worktree-end.qnt on every run and never committed. Nobody hand-picks an "interesting"
# state. One group of cases, because every rule here is a model invariant —
# there are no file-predicate-only rules the model says nothing about (unlike
# research-artifacts, which also has DIRECT cases for that reason).
#
#   MODEL-DERIVED — states from a trace, with the verdict fixed by the tool's
#     own contract. Every state of a trace through worktreeEndLifecycle
#     (verify proved NoError on all four real invariants) must PASS. The
#     final state of a counterexample against worktreeEndLifecycleBuggy — by
#     Apalache's contract, where the invariant broke — must FAIL, naming the
#     rule.
#
# Run with -v for per-case output.

set -uo pipefail

HERE="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(CDPATH="" cd "$HERE/../../.." && pwd)"
CHECKER="$HERE/check-state.sh"
MODEL="$REPO/plans/worktree-end/worktree-end.qnt"
QUINT="$REPO/node_modules/.bin/quint"

VERBOSE=0
[[ "${1:-}" == "-v" ]] && VERBOSE=1

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0

report() {
    local status="$1" name="$2" detail="${3:-}"
    if [[ "$status" == ok ]]; then
        pass=$((pass + 1))
        (( VERBOSE )) && echo "  ok    $name"
    else
        fail=$((fail + 1))
        echo "  FAIL  $name${detail:+ — $detail}"
    fi
    return 0
}

if [[ ! -x "$QUINT" ]]; then
    echo "error: $QUINT not found — run 'npm install' first." >&2
    exit 2
fi

echo "MODEL-DERIVED (fixtures regenerated from $(basename "$MODEL"))"

# Every state of a trace through a verified invariant must pass — and since
# verify proved all three real invariants NoError over the whole state space,
# any reachable state satisfies all three, not just the one used to generate
# the trace.
cd "$WORK" || exit 1
"$QUINT" run "$MODEL" --main=worktreeEndLifecycle --invariant=removedImpliesPreserved \
    --out-itf="$WORK/ok.itf.json" --max-steps=8 >/dev/null 2>&1

if [[ -s "$WORK/ok.itf.json" ]]; then
    python3 "$HERE/trace-to-fixture.py" "$WORK/ok.itf.json" "$WORK/ok" >/dev/null
    for d in "$WORK"/ok/state-*; do
        [[ -d "$d" ]] || continue
        if "$CHECKER" "$d" >/dev/null 2>&1; then
            report ok "satisfying state $(basename "$d") accepted"
        else
            report no "satisfying state $(basename "$d") accepted" "checker rejected a state the model permits"
        fi
    done
else
    report no "ok trace generated" "quint run produced no ITF"
fi

# One counterexample per real invariant, sourced from the deliberately broken
# sibling module — the real module verifies true, so it can never produce one
# against itself. verify is exhaustive and deterministic, so unlike run this
# does not depend on the simulator happening to stumble into the state.
for inv in removedImpliesPreserved remoteRemovalRequiresPush mergedRequiresInSync onDefaultRequiresExited blockedStaysInWorktree; do
    rm -rf "$WORK/_apalache-out"
    "$QUINT" verify "$MODEL" --main=worktreeEndLifecycleBuggy --invariant="$inv" \
        >/dev/null 2>&1
    cex="$(find "$WORK/_apalache-out" -name 'violation1.itf.json' 2>/dev/null | sort | tail -1)"
    if [[ -z "$cex" || ! -s "$cex" ]]; then
        report no "$inv counterexample obtained" "quint verify emitted no violation1.itf.json"
        continue
    fi
    python3 "$HERE/trace-to-fixture.py" "$cex" "$WORK/cex-$inv" >/dev/null
    last="$(find "$WORK/cex-$inv" -maxdepth 1 -name 'state-*' | sort -V | tail -1)"
    # Name the rule, not just reject the fixture: a counterexample for one
    # invariant can violate others too, so a bare rejection can pass for the
    # wrong reason. Anchored to the checker's own `FAIL <rule> - ...` line.
    out="$("$CHECKER" "$last" 2>&1)"
    if grep -qE "^FAIL $inv( |\$)" <<<"$out"; then
        report ok "$inv violation named"
    else
        report no "$inv violation named" "checker did not report $inv — got: $(head -1 <<<"$out")"
    fi
done

echo
echo "pass $pass, fail $fail"
(( fail == 0 ))
