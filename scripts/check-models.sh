#!/usr/bin/env bash
# Typecheck and test the Quint models of this checkout: each one git tracks, or the files named.
#
# Usage: check-models.sh [root] [model...]
#
# Run it as `npm run check`, which puts node_modules/.bin on PATH so `quint`
# resolves to the version package.json pins rather than whatever is installed
# globally. Run directly and it falls back to the local binary explicitly, for
# the same reason.
#
# What this does NOT do: `quint verify`. Model checking is slow, needs a JVM,
# and writes an _apalache-out/ tree into the current directory — so it stays a
# deliberate per-model command, not part of a sweep.

set -uo pipefail

REPO_ROOT="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Optional arg: a different tree to sweep (a KB repo), still using the
# harness's pinned quint.
cd "${1:-$REPO_ROOT}" || exit 1

QUINT="$REPO_ROOT/node_modules/.bin/quint"
if [[ ! -x "$QUINT" ]]; then
    echo "error: $QUINT not found — run 'npm install' first." >&2
    exit 2
fi

# macOS ships bash 3.2, which has no `mapfile` — read the list the portable way.
MODELS=""
while IFS= read -r found; do
    MODELS="${MODELS}${found}"$'\n'
# git ls-files lists this checkout's models only, so the copies in .claude/worktrees/
# (gitignored) are not checked again. A staged new model is listed too.
done < <(if (( $# > 1 )); then printf '%s\n' "${@:2}"; else git ls-files -- '*.qnt' | sort; fi)

if [[ -z "$MODELS" ]]; then
    echo "No .qnt models found. Nothing to check."
    exit 0
fi

# config: the samples of each randomized run. QUINT_SAMPLES overrides it.
SAMPLES="${QUINT_SAMPLES:-1000}"

pass=0
fail=0

while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    if ! "$QUINT" typecheck "$model"; then
        echo "FAIL typecheck - $model"
        fail=$((fail + 1))
        continue
    fi

    # `quint test` defaults the main module to the *filename*, so a file whose
    # module is named anything else fails with `QNT405 Main module not found`.
    # It also tests exactly ONE module per invocation, so every module in the
    # file needs its own call. Until 2026-10-03 this took only the first
    # `module X {` and tested that, which silently skipped the rest — a file
    # with several modules is the deliberate house pattern here (a Wide/Valid
    # pair, or a rejected reading kept so its violation stays reproducible),
    # and the first module is not reliably the one carrying the `run`s.
    MODULES=""
    while IFS= read -r found_module; do
        MODULES="${MODULES}${found_module}"$'\n'
    done < <(sed -n 's/^[[:space:]]*module[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' "$model")

    # No fallback to the bare `quint test "$model"` the first-module version
    # used: this sweep's contract is now "every module gets exercised", and a
    # file whose modules cannot be enumerated is exactly the under-tested case
    # the enumeration exists to catch. A `.qnt` with no `module` declaration
    # does not parse, so typecheck above has already failed on it.
    if [[ -z "${MODULES//[$'\n']/}" ]]; then
        echo "FAIL modules   - $model (no 'module X {' declaration found)"
        fail=$((fail + 1))
        continue
    fi

    model_failed=0
    module_count=0
    test_count=0

    while IFS= read -r main; do
        [[ -n "$main" ]] || continue
        module_count=$((module_count + 1))

        # A module with no `run` definitions is not a failure — a Wide module
        # normally has none, existing to be verified by hand rather than
        # tested. Quint 0.32.0 needs no special case for it: measured against
        # all six no-run modules in this repo, it prints the module name and
        # exits 0. The previous version of this script also tolerated a
        # non-zero exit whose output contained "0 passing"; that string is
        # never emitted by this Quint — a module whose every run fails prints
        # "N failed" and exits 1 — so the tolerance silently passed nothing
        # and was dropped on 2026-10-03 rather than left reading as if it did.
        # A run with nondet runs SAMPLES times. Quint's default of 10000 made one
        # model take 170 s. A changed model also gets quint verify at the push.
        output=$("$QUINT" test --main="$main" --max-samples="$SAMPLES" "$model" 2>&1)
        status=$?
        if (( status != 0 )); then
            echo "FAIL test      - $model [$main]"
            echo "$output" | sed 's/^/    /'
            model_failed=1
            continue
        fi

        passing=$(grep -oE '[0-9]+ passing' <<<"$output" | head -1 | cut -d' ' -f1)
        test_count=$((test_count + ${passing:-0}))
    done <<< "$MODULES"

    if (( model_failed != 0 )); then
        fail=$((fail + 1))
        continue
    fi

    # The counts are printed, not just the verdict: a module that quietly stops
    # carrying tests shows up as a number that dropped, which is how the
    # first-module gap stayed invisible for as long as it did.
    echo "ok             - $model ($module_count module(s), $test_count test(s))"
    pass=$((pass + 1))
done <<< "$MODELS"

echo
echo "models: $pass ok, $fail failed"
(( fail == 0 ))
