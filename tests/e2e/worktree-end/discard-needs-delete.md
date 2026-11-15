# worktree-end: a discard needs the word delete

## Covers

- `.claude/skills/worktree-end/`

## Setup

1. Build `$T/repo`, `$T/origin.git`, the stub `gh` and the session, as in Setup steps 1 to 3 of `merge-now.md`.
2. Ask Claude to open a worktree `wt`. Commit `x.txt` there, and do not push.

## Steps

1. Ask Claude: "close this worktree". Pick "Discard and remove".
2. At the plain-text question, type `yes`.
3. Ask again: "close this worktree". Pick "Discard and remove". Type `delete`.
4. At the retro question, pick "No".

## Expected

1. After step 1, Claude asks in plain text, not with a question box, and names the branch and its unmerged commits.
2. After step 2, Claude says the worktree is unchanged and asks the first question again. `wt` and its commit still exist.
3. After step 3, `git -C $T/repo worktree list` no longer lists `wt`, and the branch is gone.
4. `$T/gh.log` is empty: a discard calls no `gh`.
5. `git -C $T/origin.git log main` does not hold `x.txt`.

## Cleanup

1. End the Claude session.
2. Delete `$T`.
