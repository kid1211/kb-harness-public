# Findings page

## Goal

The staging page that holds the findings of one session: where it goes, what it must not hold, and how a finding moves from open to confirmed or dropped. The parent level, `session-retro`, holds the terms: session, transcript, retro and finding.

Builds: `.claude/skills/session-retro/scripts/findings-page.py`
Uses: the `kb` skill, the `personal` KB

Research, done: the answers are in `claude-research/staging/2026-10-24-session-retro/` of the `personal` KB: Q3 of `trigger-and-run.staging.md` for R7, and Q5 of `transcript-signals.staging.md` for R2. Token fields show up in 3 of 199 transcripts, so the retro needs R2.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** Each session's findings sit on one page I can review.
  Decision: pending
  Built: 1 of 1
  What Claude thinks the user means: A single place to read what the retro found.
- **F2.** No secret from the transcript lands on the page.
  Decision: pending
  Built: 1 of 1
  What Claude thinks the user means: Safe to keep and share.
- **F3.** I alone decide if a finding is confirmed or dropped.
  Decision: pending
  Built: 2 of 2
  What Claude thinks the user means: Nothing moves out of staging without my yes.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
