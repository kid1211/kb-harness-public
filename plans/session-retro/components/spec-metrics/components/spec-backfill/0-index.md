# Spec backfill

## Goal

A first run fills both tables from the past: rounds from the transcripts on disk and from the automatic commits of every branch, levels from the git history of each plan index page, and a Spec section in each existing retro page. Each backfilled row names its source.

Route: poc

Builds: `.claude/skills/session-retro/scripts/spec-backfill.py`, `tests/skills/session-retro/test-spec-backfill.sh`
Uses: `spec-rounds.py`, `spec-levels.py`, every transcript in `~/.claude/projects/`, the commit log of every branch of the harness, the retro pages in `claude-research/session-retro/` of the `personal` KB

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-28: "The retro, should recall this metric when I say trigger worktree, have a spec section", "Idk what format they have, but backfill them if you can", "just add these to retro, and use that to backfill", and "Yes record the failure, the per spec turn time and how many and so on and so for the thing we just talk about."

- **F1.** One run fills `spec-rounds.csv` from every transcript on disk, and before 2026-10-25 from the `[automatic after <skill>]` commits of every branch, with the minutes left empty.
- **F2.** One run fills `spec-levels.csv` from the commit history of each plan index page.
- **F3.** One run adds a Spec section to each existing retro page of a session that ran spec. A page that already has one is left as it is, so a second run changes nothing.
- **F4.** Each backfilled row names its source: transcript, commits or plan history.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
