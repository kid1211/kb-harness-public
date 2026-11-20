# Nested instructions

## Goal

When Claude reads or edits a file in an added folder, a hook gives Claude each `CLAUDE.md` between that file and the root of its repo, once per session. Claude Code does this on its own only in the start folder.

Route: poc

Builds: `.claude/hooks/nested-instructions.sh`, `.claude/settings.json` (its PostToolUse and InstructionsLoaded lines), and `tests/global/nested-instructions/`
Uses: the `PostToolUse` hook input, the research answer on nested `CLAUDE.md` files in the parent level

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, from the parent level `plans/global/components/multi-folder/`.

- **F1.** After a Read, Edit or Write of a file outside the start folder, Claude gets each `CLAUDE.md` of the folders above that file, up to its repo root. *(the user, 2026-11-19)*
- **F2.** Each `CLAUDE.md` comes once per session, not on each read. *(the user, 2026-11-19)*
- **F3.** A file in the start folder gets nothing from the hook, since Claude Code loads those already. *(the user, 2026-11-19)*
- **F4.** The hook never blocks a call. If it fails, the call goes on. *(the user, 2026-11-19)*
- **F5.** On each read or edit, the hook checks that the instructions of the file's folder are loaded. If the file's repo is not the start folder and was not added, the hook gives the top instructions file too. *(the user, 2026-11-20)*
- **F6.** The hook notes each instructions file that Claude Code loads itself, and never gives it again. The folder pane lists what the session has. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
