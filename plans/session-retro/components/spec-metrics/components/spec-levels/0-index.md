# Spec levels

## Goal

An SCD type 2 table of the plan levels in spec-levels.csv: state, Built, and open questions, with valid_from, valid_to and is_current, updated by each retro.

Route: poc

Builds: `.claude/skills/session-retro/scripts/spec-levels.py`, `.claude/skills/session-retro/scripts/retro.sh` (its call of `spec-levels.py`), `tests/skills/session-retro/test-spec-levels.sh`
Uses: the plan index pages under `plans/`, `.claude/skills/p-z-helper-file-structure/scripts/next-step.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-28: "The retro, should recall this metric when I say trigger worktree, have a spec section", "Idk what format they have, but backfill them if you can", "just add these to retro, and use that to backfill", and "Yes record the failure, the per spec turn time and how many and so on and so for the thing we just talk about."

- **F1.** Each retro updates `claude-research/session-retro/spec-levels.csv`, an SCD type 2 table of the plan levels the session touched: level, state, Built x of y, open questions, valid_from, valid_to and is_current.
- **F2.** A level whose values did not change gets no new row. A changed level gets a new current row, and its old row gets a valid_to.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
