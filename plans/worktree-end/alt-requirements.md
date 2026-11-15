# Worktree end: changed requirements

## R3. A blocked merge stays put

Changed 2026-10-20. It came from §6 of `plans/cleanup.md`, which is now removed.

Before: if `gh pr merge` failed, Merge now ran `ExitWorktree(keep)`.

Why it changed: on 2026-10-20, `gh pr merge` refused PR #52. `main` had new commits, and the merge had a conflict. The session left the worktree and had to enter it again by path to fix the conflict. ExitWorktree cannot remove a worktree that a session entered by path, so the end needed a forced `git worktree remove`.

## R5, R6. Scripts, and a skill that is execution only

Changed 2026-10-20, on the user's request. Before: `SKILL.md` held about 300 lines of steps, history and rationale, and the model and its tests sat in the skill folder. The user runs this skill often, so each run spent many tokens on prose and on reading command output.

## R8. Merge now commits first

Added 2026-10-23. Before: any uncommitted change stopped every choice. Now Merge now commits them first.

## R9. Ask for a retro

Added 2026-10-24, for R1 of `plans/session-retro/`.
