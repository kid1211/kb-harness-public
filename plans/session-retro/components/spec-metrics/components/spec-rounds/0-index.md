# Spec rounds

## Goal

One row per spec round of the session in spec-rounds.csv, with its times, turns, failures and the user's prompts by kind, and a Spec section on the session's retro page against the running median.

Route: poc

Builds: `.claude/skills/session-retro/scripts/spec-rounds.py`, `.claude/skills/session-retro/scripts/retro.sh` (its call of `spec-rounds.py`), `.claude/skills/session-retro/scripts/commit-page.sh` (it takes `spec-rounds.csv` too), `tests/skills/session-retro/test-spec-rounds.py`
Uses: the session transcript, the commit log of the harness, `claude-research/spec-performance/scripts/rounds.py` of the `personal` KB (the method to start from)

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-28: "The retro, should recall this metric when I say trigger worktree, have a spec section", "Idk what format they have, but backfill them if you can", "just add these to retro, and use that to backfill", "Yes record the failure, the per spec turn time and how many and so on and so for the thing we just talk about.", and "We also release retro to public, the public one have no spec, so I don't want retro break".

- **F1.** Each retro appends one row per spec round of the session to `claude-research/session-retro/spec-rounds.csv`: session, level, step, end time, Claude minutes, minutes waiting on me, model minutes, tool minutes, subagents and their minutes, and turns in the round.
- **F2.** Each row also holds the failures of the round: Stop-hook blocks by hook, failed checks or tests, rejected tool calls, and interrupts.
- **F3.** Each row also counts my prompts in the round by kind: status ("all built?"), confused ("what does that mean?"), continue ("go", "yes") and skip-checks ("skip the quint verify").
- **F4.** The retro page of the session gets a Spec section: its numbers next to the running median of all rows, each worse one marked. A session with no spec round gets no Spec section.
- **F5.** The retro does not break where spec is not added, such as the public release: with no spec round, or with no `spec-rounds.py`, it logs "spec rounds: skipped for now" and writes the page as before.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
