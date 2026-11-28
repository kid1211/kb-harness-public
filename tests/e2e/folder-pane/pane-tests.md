# folder-pane: the mod passes its tests, and a session with it loads

## Covers

- `.claude/skills/folder-pane/`

## Setup

1. Make a temp folder `$T`, outside any git repo.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.

## Steps

1. In `$T/h`, run `claude plugin test .claude/skills/folder-pane`.
2. In `$T`, run `claude -p --plugin-dir $T/h/.claude/skills/folder-pane "Say READY."`.

## Expected

1. Step 1 prints `0 fail`, and `19 pass` or more.
2. Each test that starts with `promptTest:` is on a `(pass)` line of step 1. A pick puts the text of the domain in the box.
3. The test `pane: /worktrees toggle opens it` is on a `(pass)` line too. Only a made worktree opens in VS Code.
4. Step 2 exits 0 and prints `READY`. It prints no error that names `folder-pane`.

## Cleanup

1. Delete `$T`.
