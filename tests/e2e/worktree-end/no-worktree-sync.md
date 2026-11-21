# worktree-end: the worktree-sync skill is gone

The `worktree-sync` skill was removed on 2026-11-20. It was only `git fetch` and `git rebase`, so it was no longer needed. After a refused merge, `worktree-end` offers a rebase onto `origin/<default>` by hand.

## Covers

- `.claude/skills/worktree-sync/`
- `tests/e2e/worktree-sync/`

## Setup

1. Check out the commit under test, of the harness or of the public repo.

## Steps

1. Run `ls .claude/skills/worktree-sync tests/e2e/worktree-sync`.
2. Run `bash tests/skills/worktree-end/test-no-worktree-sync.sh`.
3. Start a Claude session in the checkout. Ask it: "sync this worktree with main".

## Expected

1. `ls` finds neither folder.
2. The script prints `ok   no worktree-sync left` and exits 0.
3. Claude names no `worktree-sync` skill and loads none. It may run `git fetch` and `git rebase` itself.

## Cleanup

Nothing to clean.
