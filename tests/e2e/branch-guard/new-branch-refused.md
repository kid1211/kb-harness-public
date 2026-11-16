# branch-guard: a fresh clone refuses a new branch in its main checkout

## Covers

- `.claude/hooks/branch-guard.sh`
- `.claude/settings.json`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Write the hook input of a Bash call: `{"tool_input": {"command": "<cmd>"}, "cwd": "$T/h"}`, with `<cmd>` each command of the steps.

## Steps

1. In `$T/h`, run `bash tests/global/hooks/test-branch-guard.sh`.
2. Pipe the hook input of `git checkout -b try` to `bash $T/h/.claude/hooks/branch-guard.sh`. Keep its exit code and its error text.
3. Do the same for `git switch main`.
4. Do the same for `git status`.
5. Make a worktree with `git -C $T/h worktree add -q $T/h/.claude/worktrees/w`. Then pipe the input of `git checkout -b try`, with `cwd` set to `$T/h/.claude/worktrees/w`.

## Expected

1. Step 1 ends with `branch-guard: <n> passed, 0 failed`.
2. Step 2 exits with code 2, and its error text names `EnterWorktree`.
3. Step 3 exits with code 2, and its error text names `git checkout`.
4. Step 4 exits with code 0 and prints nothing.
5. Step 5 exits with code 0: a new branch in a worktree is allowed.
6. `git -C $T/h branch --list try` prints nothing after step 2.

## Cleanup

1. Delete `$T`.
