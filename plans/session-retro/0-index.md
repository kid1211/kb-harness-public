# Session retro

## Goal

After `worktree-end` finishes, look back at the session that just ended. Find the hook blocks, the loops of duplicate work, and the back-and-forth with the user. For each one, say what to change in the harness and what the user can do better. Write the findings into a staging page of the `personal` KB. A reminder makes the user read the findings from time to time and pick what to fix.

Builds: `.claude/skills/session-retro/`, the `SessionStart` entry in `.claude/settings.json`, `tests/skills/session-retro/`
Uses: `worktree-end`, the session transcript in `~/.claude/projects/`, `claude -p`, the `personal` KB

The answers are staging pages in the `personal` KB, in `claude-research/staging/2026-10-24-session-retro/`:

- `trigger-and-run.staging.md`: R1, R2, R10, R14, and the domain of `findings-page`. The ExitWorktree hook, the headless fork and its cost, the domain, and the weekly reminder.
- `transcript-signals.staging.md`: the `findings` component. How blocks show in a transcript, how often each hook blocked, and what a script can find.
- `anthropic-features.staging.md`: R7. `/insights` covers part of `findings`, and its three layers are the example to build from (Q4). Nothing else covers it.
- `hermes-learning-loop.staging.md`: R7, R10. Ideas to copy, no code to lift.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** After a session closes, I choose whether a retro runs.
  Decision: pending
  Built: 2 of 2
  What Claude thinks the user means: I want it only when I say yes, with no new turns.
- **F2.** The retro finds hook blocks, loops and my corrections, and says what to change.
  Decision: pending
  Built: 2 of 2
  What Claude thinks the user means: I want lessons from each session.
- **F3.** Findings land on one page that I settle, and a weekly reminder counts the open ones.
  Decision: pending
  Built: 3 of 3
  What Claude thinks the user means: I want a record I act on, and a nudge.
- **F4.** The retro reuses what Anthropic already offers.
  Decision: pending
  Built: 1 of 1
  What Claude thinks the user means: I want no rebuilt wheel.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
