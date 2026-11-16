---
name: kb
description: Read and write a knowledge base in the three-area layout - source (the real-world record), staging (Claude's area) and consolidated (what the user confirmed, with their score). Holds the layout, the shared check `kb-check.py`, and the hooks that guard each write.
when_to_use: Use whenever Claude reads facts out of a KB or writes a KB file, and on `/kb check`, `/kb todo` and `/kb recheck <topic>`. `p-research` calls its check. Skip for files under `plans/` and for the harness itself.
user-invocable: true
---

# KB

Plan: `plans/knowledge-base-architecture/`. `C` below stands for `python3 -I .claude/skills/kb/scripts/kb-check.py`.

## The layout

Each topic folder, such as `member/colon-issue/`, holds its three areas side by side. The name gives the area:

| Name | Area |
|---|---|
| `name.source.<ext>`, also `IMG_3724.source.jpeg` | source: kept as it came in |
| `name.staging.<ext>` | staging: Claude's area |
| `name.md` | consolidated: what the user confirmed |
| `CLAUDE.md`, a dot folder, `plans/` | exempt |

- **Research runs:** a domain can hold `staging/<YYYY-MM-DD>-<slug>/`, one folder per `p-research` run, with its `.staging.md` pages. It is the one sub-folder for an area.
- **Source** starts its name, or a folder it is in, with the event date: `YYYY-MM-DD`, `YYYY-MM` or `YYYY`. If no part is known, it starts with `undated-`, and the file says the day it came in.
- **Consolidated** has the user's score at its root: frontmatter `confidence: 1|2|3` and `confirmed: YYYY-MM-DD`, or the line `Confidence: N, YYYY-MM-DD` under the title. A heading can carry its own line. A heading with none takes its parent's. 3 is checked against source, 2 sure, 1 likely.
- **A changed fact** gets `Changed YYYY-MM-DD: <old> to <new>, from <source link>` under its heading. Git holds the rest.
- **Sources:** each fact carries `[n]`. A `## Sources` list links each `n` to a `.source.` file by a relative path. A staging page may cite a URL with its retrieval date.
- **Missing information:** `TODO(P1): <what is missing>` under its heading, P1 to P3. Write marks on staging pages only. Propose the priority. The user's priority wins.

## Read

1. Read the consolidated page of the topic first, and note each heading's score.
2. Then staging, for what is not confirmed yet. Say so when you use it.
3. Settle a fact that matters against its source.

## Write

1. Write KB files with Write or Edit, never through Bash. A Bash write skips the guard, and the after hook names it. If it does, tell the user which files changed.
2. Write freely in staging.
3. For a new source, name it with its event date. Do not change an existing source file: the hook asks the user.
4. For a consolidated page, write the whole page with its score and sources. The hook refuses an incomplete page, then asks the user.
5. After a staging write, the hook shows the confirmed headings of the topic. Compare. If a fact disagrees:
   - write `TODO(P1): conflict with <page>#<heading>: <both values and their sources>` in the staging page,
   - tell the user, and propose `/op-fork-new-wt` to settle it,
   - do not edit the consolidated page.

## Commands

- `/kb check`: run `C all <kb>`. Report each line. The last lines list consolidated pages with uncommitted changes: ask the user to look at each.
- `/kb todo`: run `C todo <kb>`. Show the list, P1 first.
- `/kb recheck <topic>`: start a fresh agent. Give it the topic folder's consolidated pages, its staging pages, and each source newer than a page's `confirmed` date. Ask it for each fact that disagrees, with both values and their sources. Write a `TODO(P1)` mark per conflict into the topic's staging page, then tell the user.

## Hooks

`hooks/kb-guard.sh` (PreToolUse) and `hooks/kb-after.sh` (PostToolUse), on Write, Edit, MultiEdit and Bash. They are not in `settings.json` yet: today's KB files have no suffix, so the guard would ask on every write until the move of today's files (plan R26).

Tests: `python3 -I .claude/skills/kb/scripts/kb-check.py --test` and `bash tests/skills/kb/test-kb-hooks.sh`.
