# draw-graph: the skill names files that exist, and its hook suite passes

## Covers

- `.claude/skills/draw-graph/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.

## Steps

1. In `$T/h`, run `bash .claude/skills/draw-graph/tests/test-no-mermaid.sh`.
2. Read `$T/h/.claude/skills/draw-graph/SKILL.md`. List each path it names under `.claude/`.

## Expected

1. Step 1 exits 0 and prints no line that starts with `FAIL`.
2. Each path of step 2 is a file or a folder in `$T/h`.

## Cleanup

1. Delete `$T`.
