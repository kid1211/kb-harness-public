# op-fork: the suite passes, and a run outside cmux opens nothing

## Covers

- `.claude/skills/op-fork-keep/`
- `.claude/skills/op-fork-new-wt/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make a throwaway git repo `$T/r` with one commit.

## Steps

1. In `$T/h`, run `bash tests/skills/op-fork/test-op-fork.sh`. It uses a stub `cmux` and a stub `claude`.
2. In `$T/r`, run `env -u CMUX_SURFACE_ID CLAUDE_CODE_SESSION_ID=abcdef1234 bash $T/h/.claude/skills/op-fork-keep/scripts/fork.sh`.
3. In `$T/r`, run the same command with `--new-wt` at the end.
4. In `$T/r`, run `env -u CLAUDE_CODE_SESSION_ID bash $T/h/.claude/skills/op-fork-keep/scripts/fork.sh`.

## Expected

1. Step 1 ends with `op-fork: <n> passed, 0 failed`.
2. Step 2 prints one line that starts with `op-fork-keep: this session is not inside cmux. Nothing opened. Run by hand: cd` and ends with `claude --resume abcdef1234 --fork-session`. Its exit code is 1.
3. Step 3 prints one line that starts with `op-fork-new-wt: this session is not inside cmux.` and ends with `--fork-session -w fork-abcdef12`. Its exit code is 1.
4. Step 4 prints `op-fork-keep: no session ID (CLAUDE_CODE_SESSION_ID is not set). Nothing opened.`, with exit code 1.
5. After steps 2 to 4, `git -C $T/r worktree list` shows one worktree, and `$T/r/.claude/worktrees/` does not exist.

## Cleanup

1. Delete `$T`.
