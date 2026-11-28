# kb: a fresh clone runs the KB check and the guard hooks

## Covers

- `.claude/skills/kb/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.

## Steps

1. In `$T/h`, run `python3 -I .claude/skills/kb/scripts/kb-check.py --test`.
2. In `$T/h`, run `bash tests/skills/kb/test-kb-hooks.sh`. It builds its own throwaway KB.
3. Read `$T/h/.claude/skills/kb/SKILL.md`. List each script path it names under `hooks/` or `scripts/`.

## Expected

1. Step 1 exits 0 and ends with `<n> of <n> pass`, the same `<n>` twice.
2. Step 2 exits 0 and ends with `<n> passed, 0 failed`.
3. Each path of step 3 is a file in `$T/h/.claude/skills/kb/`.

## Cleanup

1. Delete `$T`.
