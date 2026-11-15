# worktree-end: Merge now commits, merges and removes the worktree

## Covers

- `.claude/skills/worktree-end/`

## Setup

1. Make a temp folder `$T`. Make a bare repo `$T/origin.git`, clone it to `$T/repo`, commit a `.gitignore` that holds `.claude/` on `main` and push. Set `origin/HEAD` to `main`.
2. Link `.claude/skills/` of the harness checkout under test to `$T/repo/.claude/skills`. After step 4 opens the worktree, link it there too.
3. Put a stub `gh` first on `PATH`, in `$T/bin`. It logs each call to `$T/gh.log`. `pr view` fails until `pr create` runs. `pr merge` merges the branch into `main` of `$T/origin.git` by squash. After that, `pr view` prints `MERGED`.
4. Start a Claude session in `$T/repo`. Ask it to open a worktree `wt` (`EnterWorktree`). Write `new.txt` in the worktree, with no commit.

## Steps

1. Ask Claude: "close this worktree".
2. At the first question, pick "Merge now".
3. At the retro question, pick "No".

## Expected

1. The first question has the options Merge, Switch away for now, Merge now, and Discard and remove, in that order. Claude names `new.txt` as a file Merge now commits.
2. Claude stages `new.txt` by path, not by `git add -A`, and commits it.
3. `$T/gh.log` holds `pr create` and then `pr merge ... --squash --match-head-commit`.
4. `git -C $T/origin.git show main:new.txt` prints the file.
5. `git -C $T/repo worktree list` no longer lists `wt`. The branch `worktree-wt` is gone.
6. `$T/repo` is on `main`, with a clean `git status`.
7. Claude asks "Run a session retro?". On "No" it starts nothing: no `retro.sh` process runs.

## Cleanup

1. End the Claude session.
2. Delete `$T`.
