# writing-mode: the mod passes its tests, and a session gets the casual prompt

## Covers

- `.claude/skills/writing-mode/`

## Setup

1. Make a temp folder `$T`, outside any git repo.
2. Read `~/.claude/writing-check-mode.json`. Do not change it. If it does not exist, each mode is `pro`.

## Steps

1. Run `claude plugin test .claude/skills/writing-mode` from the harness checkout under test.
2. In `$T`, run `claude -p --plugin-dir <checkout>/.claude/skills/writing-mode "Quote, word for word, each line of your system prompt that starts with 'Writing mode for'. If none, say NONE."`

## Expected

1. Step 1 prints `0 fail`, and a pass count of at least 12.
2. If the `reply` mode of setup step 2 is `casual`, step 2 quotes a line that starts with `Writing mode for replies: casual.`
3. If the `docs` mode is `casual`, step 2 quotes a line that starts with `Writing mode for docs you write: casual.`
4. If neither mode is `casual`, step 2 prints `NONE`.
5. `~/.claude/writing-check-mode.json` is the same as in setup step 2.

## Cleanup

1. Delete `$T`.
