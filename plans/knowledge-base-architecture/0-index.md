# Knowledge base architecture

## Goal

A new layout for every KB, in three areas. Source is the record of what happened in the real world. Staging is where Claude works. Consolidated holds what the user confirmed. The layout says how each page links back to source, how time is kept, how the user's confidence is kept, and how a conflict reaches the user. The kb- skills and `p-research` are then rebuilt on it. Draft.

Builds: the KB layout rules in `.claude/CLAUDE.md`, the skill `.claude/skills/kb/` with its check script `.claude/skills/kb/scripts/kb-check.py`, its hooks in `.claude/skills/kb/hooks/` and their lines in `.claude/settings.json`, and the KB file names in each skill that saves a KB file. The skills `read-from-kb` and `trigger-kb-adoc` go.
Uses: the research page `personal/claude-research/knowledge-base-architecture-research-2026-10-23.md` (written, not built here), the `personal` and `eventPNL` KBs, `media-icloud-sync`, `kb-commit-nudge.sh`, `op-fork-new-wt`, `ocr-translate-medical-record`, and `p-research`, which its own plan `plans/p-spec-skill/components/p-spec/components/p-research/` changes to this layout

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** Every KB has three areas: source, staging and consolidated.
  Decision: pending
  Built: 0 of 3
  What Claude thinks the user means: I want the real record, Claude's work and my confirmed pages kept apart.
- **F2.** Every claim links back to its source, and source keeps its date.
  Decision: pending
  Built: 0 of 2
  What Claude thinks the user means: I want to check any fact against the original in one click.
- **F3.** Consolidated pages carry my confidence, and a conflict comes to me first.
  Decision: pending
  Built: 0 of 3
  What Claude thinks the user means: I want Claude never to edit a confirmed page on its own.
- **F4.** One shared check and one KB skill enforce the layout, folder by folder.
  Decision: pending
  Built: 0 of 5
  What Claude thinks the user means: I want rules applied by tools, adopted gradually, with research found first.

## Open questions

- ⚠️ built check 2026-11-02 (Frieren): [major] R27 folder list is not built (needs the user's answer on where the list lives, see the designed-check item). [major] The kb hooks are not in `settings.json` and `read-from-kb` and `trigger-kb-adoc` still exist, so R28's removals did not happen. SKILL.md:55 cites the dropped R26. [major] R7 compare covers staging only, not a new source. minor: the R29 run folder gets no compare, the hook suite tests Write only, `uncommitted` skips renames, the Bash flag scans all KBs, `DATE` takes any four digits. Build moved the tests to `tests/skills/kb/` and left `hooks/` in the skill (conflict with the `lean` check: the user or p-design decides).
- ⚠️ designed check 2026-11-02 (Frieren, nothing in a test shows these; the build shows whether each is real):
  - A file in a folder not on the R27 list, and a name with no area, have no edge in the graph (`which-area?`, architecture.md:33). Where the list lives and what the hook does with them is not set.
  - The research run folder of R29 (`staging/<date>-<slug>/`) holds no consolidated pages, so the compare of 1-design.md:76 and :83 finds nothing, and it matches the event-folder rule.
  - R7 says a new source is compared, but only `free` leads to `comparing` (architecture.md:34).
  - minor: Bash-written staging skips `comparing`. minor: `userTold` and `userYes` have two meanings in the model. minor: Coverage cites R8 (replaced by R28). minor: the model header still names the migrate component. minor: `skill-updates` lists `media-icloud-sync`, which is on `Uses:` not `Builds:`. minor: "applies `old_string` to `new_string`" is backwards (1-design.md:94). minor: `score` does not require the `confirmed` date of R22.

## Research questions

### the user

None.

### Claude

None.
