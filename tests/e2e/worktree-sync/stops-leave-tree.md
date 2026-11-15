# worktree-sync: each stop leaves the tree as it was

## Covers

- `.claude/skills/worktree-sync/`

## Setup

1. Build `$T/repo`, `$T/origin.git` and the worktree `feat`, as in Setup steps 1 to 5 of `rebase-clean.md`.
2. In `$T/other`, change line 1 of `b.txt`, commit on `main` and push. In the worktree, `feat` changes line 1 of `b.txt` too, so a rebase conflicts.
3. Keep `git rev-parse HEAD` of the worktree as `$H`.

## Steps

1. In `$T/repo` (the main checkout, not a worktree), ask Claude: "sync this worktree".
2. In the worktree, write `dirty.txt` with no commit. Ask Claude: "sync this worktree".
3. Delete `dirty.txt`. Ask Claude: "sync this worktree".

## Expected

1. Step 1: the script exits with 0. Claude says it runs only in a worktree. `git rev-parse HEAD` in the worktree is still `$H`.
2. Step 2: the script exits with 1. Claude asks the user to commit or stash, and runs no `git stash`. `git stash list` prints nothing. `dirty.txt` is still there.
3. Step 3: the script exits with 3. Claude names `b.txt` as the conflict. `git status` says a rebase is in progress. Claude ran no `git rebase --abort`.

## Cleanup

1. Run `git rebase --abort` in the worktree.
2. Delete `$T`.
