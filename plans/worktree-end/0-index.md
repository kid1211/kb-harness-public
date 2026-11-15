# Worktree end

## Goal

Close a worktree that EnterWorktree opened: merge it through a pushed branch and a PR, leave it for now, or discard it. Scripts make every git and gh decision and print one short line, so the skill spends few tokens.

Builds: `.claude/skills/worktree-end/`, `tests/skills/worktree-end/`
Uses: `worktree-sync`, `gh`, ExitWorktree, `session-retro`

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

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
