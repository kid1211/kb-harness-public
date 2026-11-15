# worktree-sync: a clean rebase onto a newer main

## Covers

- `.claude/skills/worktree-sync/`

## Setup

1. Make a temp folder `$T`. Every path below is in it.
2. Make a bare repo `$T/origin.git`. Clone it to `$T/repo`, add `a.txt` and a `.gitignore` that holds `.claude/`, commit on `main` and push.
3. In `$T/repo`, add a worktree `$T/repo/.claude/worktrees/feat` on a new branch `feat`. Commit `b.txt` there.
4. In a second clone `$T/other`, commit `c.txt` on `main` and push. Now `origin/main` is one commit ahead of the base of `feat`.
5. Link `.claude/skills/` of the harness checkout under test to `.claude/skills` in `$T/repo` and in the worktree, so both see `worktree-sync`. The `.gitignore` keeps the links out of `git status`.

## Steps

1. In `$T/repo/.claude/worktrees/feat`, ask Claude: "sync this worktree".
2. Claude runs `bash .claude/skills/worktree-sync/scripts/sync.sh` there.

## Expected

1. The script exits with 4.
2. `git log --format=%s origin/main..feat` prints only the commit of `b.txt`.
3. `git merge-base feat origin/main` equals `git rev-parse origin/main`.
4. `c.txt` exists in the worktree.
5. The local `main` ref of `$T/repo` did not move: it equals its value after Setup step 2.
6. `git status --porcelain` in the worktree prints nothing.
7. Claude's reply says the branch was rebased, and names what was rebased.

## Cleanup

1. Delete `$T`.
