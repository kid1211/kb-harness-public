# markdown-diff: a fresh clone renders the diff of two Markdown files

## Covers

- `.claude/lib/markdown-diff/`
- `.claude/lib/code-reference/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test. Then run `npm ci` in `$T/h`.
3. Write `$T/old.md` with `# Notes`, a blank line, and `The quick fox jumps.`
4. Write `$T/new.md` with `# Notes`, a blank line, `The quick red fox leaps.`, a blank line, and `## Added part`.

## Steps

1. In `$T/h`, run `node --test .claude/lib/markdown-diff/tests/markdown-diff.test.js`.
2. In `$T/h`, run `node --test .claude/lib/code-reference/tests/code-reference.test.js`.
3. In `$T/h`, run a node script that reads the two files and prints `render(old, new, { marked, Diff })`. It takes `render` from `./.claude/lib/markdown-diff/markdown-diff.js`, `marked` from the package `marked`, and `Diff` from the package `diff`. Write the output to `$T/out.html`.

## Expected

1. Step 1 prints `fail 0`.
2. Step 2 prints `fail 0`.
3. `$T/out.html` holds `<h1>Notes</h1>` with no mark on it.
4. `$T/out.html` holds `<del>jumps</del><ins>leaps</ins>` inside a block with the class `md-chg`.
5. `$T/out.html` holds `<div class="md-ins"><h2>Added part</h2>`.

## Cleanup

1. Delete `$T`.
