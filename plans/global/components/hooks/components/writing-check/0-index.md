# Writing check

## Goal

Two hooks check what Claude writes against the writing rules in `.claude/hooks/writing-rules.md` and the Terms table of `.claude/CLAUDE.md`: each reply, and the text each edit of a markdown file adds. If a rule scores under its threshold, the hook sends the failures back to Claude, who fixes the text. It never blocks a write. 16 requirements, 1 component. The `writing-mode` mod that R9 and R11 name is built by `plans/global/components/mod/components/writing-mode/`. Draft.

Builds: `.claude/hooks/writing-check.py`, `.claude/hooks/writing-rules.md`, `.claude/settings.json` (its `PostToolUse` and `Stop` lines), `.claude/CLAUDE.md` (its Terms table and the `@` import of the rules file), the e2e test `tests/e2e/writing-check/`, and its line in the Tests of `CLAUDE.md`
Uses: `claude_code`, the `PostToolUse` and `Stop` hooks of Claude Code, the config pane of the writing-mode mod, the release list, scans and settings filter of `plans/public-release/` (`public-release/R42`, `public-release/R54`, `public-release/R56`)

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** Claude's replies and doc edits are checked against my writing rules.
  Decision: pending
  Built: 4 of 6
  What Claude thinks the user means: I want failures sent back to Claude to fix, never a blocked write.
- **F2.** I can switch the checks off, casual or pro, for replies and for docs.
  Decision: pending
  Built: 1 of 1
  What Claude thinks the user means: I want control of how strict the checks are.
- **F3.** I can tune the checks from a log and a report.
  Decision: pending
  Built: 3 of 3
  What Claude thinks the user means: I want to see the scores and move thresholds with evidence.
- **F4.** The checks skip text that must stay as written, and ask for full file paths.
  Decision: pending
  Built: 3 of 3
  What Claude thinks the user means: I want quotes, code and raw research left alone, and paths I can open.
- **F5.** The public release ships writing-check, so the config pane and the hooks work in the public nightly.
  Decision: keep
  Built: 0 of 4
  What Claude thinks the user means: I want a public user to get the same checks and report pane that I get, with nothing private in them.

## Open questions

1. ✅ When the user asks for another tone, the hook still checks against these rules. Recommendation: accept the extra feedback for now, and look again if the log shows it often.
   - Answer: accept the extra feedback for now. *(Claude, 2026-11-23, recommended)*

## Research questions

### the user

None.

### Claude

1. [defer] open Does the transcript always hold the last reply when the `Stop` hook runs? If the input has `last_assistant_message`, the script uses that first.
