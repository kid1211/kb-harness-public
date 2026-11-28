# Spec metrics

## Goal

Each retro records how spec ran in the session: one row per spec round and an SCD type 2 table of plan levels, in shared files of the personal KB. The session's retro page gets a Spec section that holds its numbers against the running median. A first run backfills the old sessions.

Route: split

Builds: `plans/session-retro/components/spec-metrics/components/` (its parts)
Uses: the transcripts in `~/.claude/projects/`, the `[automatic after <skill>]` commits, the plan index pages, the `personal` KB

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-28: "The retro, should recall this metric when I say trigger worktree, have a spec section", "Idk what format they have, but backfill them if you can", "just add these to retro, and use that to backfill", and "Yes record the failure, the per spec turn time and how many and so on and so for the thing we just talk about."

- **F1.** After `worktree-end` runs the retro, the retro page of the session has a Spec section with how spec ran in it.
- **F2.** The numbers of every session sit in two shared files in `claude-research/session-retro/` of the `personal` KB, so the medians and trends keep their history after Claude Code deletes old transcripts.
- **F3.** The old sessions get their numbers too, from what is still on disk and in the commit history, and each old row says where it came from.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
