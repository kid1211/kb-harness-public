# Findings

## Goal

What the retro looks for in a transcript: hook blocks, loops of duplicate work, and places where the user corrected Claude. Each finding gives its cause, a change to the harness, and a tip for the user where one applies. The parent level, `session-retro`, holds the terms: session, transcript, retro and finding.

Builds: `.claude/skills/session-retro/scripts/findings.py`, `.claude/skills/session-retro/references/findings-kinds.md`, `.claude/skills/session-retro/references/findings-prompt.md`
Uses: the session transcript

Research, done: the answers are in `transcript-signals.staging.md`, in `claude-research/staging/2026-10-24-session-retro/` of the `personal` KB: Q1 and Q2 for R7, Q3 for R2, Q4 for R3. R4 comes from Q4 of `anthropic-features.staging.md`, on how `/insights` builds its report.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** The retro finds each block and says if it was right.
  Decision: pending
  Built: 6 of 6
  What Claude thinks the user means: I want hook blocks counted and judged.
- **F2.** The retro finds loops and duplicate work.
  Decision: pending
  Built: 4 of 4
  What Claude thinks the user means: I want repeated work named.
- **F3.** The retro finds where I corrected Claude.
  Decision: pending
  Built: 4 of 4
  What Claude thinks the user means: I want my corrections turned into findings.

## Open questions

- ⚠️ built check 2026-11-02 (Frieren, all minor): `findings.py:158` lets a finding with no `uuid` pass (None in the set). The design line "scan reads `version`" has no code. Interrupts form one group. A failed Edit or a Bash change confuses loop candidates. A group is unseen by its last event but cites its first. `reply_list` takes the first JSON list in prose.
1. ✅ designed check 2026-11-02 (Frieren): the three [major] findings are now R8, R9 and R10 in `req-active.md`, and the design and model follow them. The minor items need no requirement. *(Claude, 2026-11-02, recommended)*

## Research questions

### User

None.

### Claude

None.
