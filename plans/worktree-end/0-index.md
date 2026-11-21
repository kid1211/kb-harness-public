# Worktree end

## Goal

Close a worktree that EnterWorktree opened: merge it through a pushed branch and a PR, leave it for now, or discard it. Scripts make every git and gh decision and print one short line, so the skill spends few tokens.

Builds: `.claude/skills/worktree-end/`, `tests/skills/worktree-end/`, and the removal of `.claude/skills/worktree-sync/` and `tests/e2e/worktree-sync/`
Uses: `gh`, ExitWorktree, `session-retro`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** I close a worktree by merge through a PR, leave it, or discard it.
  Decision: pending
  Built: 4 of 4
  What Claude thinks the user means: One skill for every way a worktree ends.
- **F2.** Nothing is lost unless I type delete.
  Decision: pending
  Built: 2 of 2
  What Claude thinks the user means: Commits are safe until I say otherwise.
- **F3.** The skill is cheap to run and offers a session retro at the end.
  Decision: pending
  Built: 3 of 3
  What Claude thinks the user means: Scripts decide, so few tokens go to git output.
- **F4.** Remove the `worktree-sync` skill. It is only `git fetch` and `git rebase`, so it adds little. Done 2026-11-20: the skill is removed. *(the user, 2026-11-20)*
  Decision: keep
  Built: 0 of 2
  What Claude thinks the user means: One worktree skill is left, and nothing points to the one that is gone.

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
