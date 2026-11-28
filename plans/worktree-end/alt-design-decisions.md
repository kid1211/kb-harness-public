# Worktree end: designs not chosen

## One model per rule

Not chosen. The rules share state (`pushed`, `inSync`, `merged`, `removed`, `kept`), so they are facets of one lifecycle. One machine holds them all, and each invariant is checked against every move.

## A local merge branch

Not chosen (2026-09-15, on the user's direction). A local merge needs the primary checkout, which the sandbox restricts.

- Every merge goes through a pushed branch and a PR.
- A PR can target any branch, so the model has no target variable.

## `ExitWorktree(keep)` after a blocked merge

Replaced (2026-10-20). Before: a refused `gh pr merge` left the worktree.

- The session had to enter it again by path.
- ExitWorktree cannot remove a worktree that a session entered by path.
- Now the session stays in the worktree, and `merge_blocked` leads back to `start` after a fix.

## Phase names in camelCase

Replaced (2026-11-02). The phases were `blockedDirty`, `remoteCheck` and so on. The design check reads a state node as lowercase words joined by `_`, so the phases are now `blocked_dirty`, `remote_check` and so on.
