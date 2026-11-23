# Knowledge base architecture: changed requirements

## R2. Three areas

**Requirement:** Each domain has three areas: source, staging and consolidated. A reader can tell the area of a file from its path or name.

**Why it is not chosen:** The user put the three areas in each topic folder, not once per domain, and picked a dot suffix to name the area. Replaced by R9 and R10. Dropped 2026-10-23.

## R3. Source is the record

**Requirement:** Source holds what happened, as it came in: a photo, a scan, an export, an OCR text, a fact the user tells. It is in time order, and the date of the event is in its path or name. Media stay in iCloud through `media-icloud-sync`.

**Why it is not chosen:** The user asked for a check that each source file records when it happened. Replaced by R11. Dropped 2026-10-23.

## R5. Staging is Claude's area

**Requirement:** Claude can index, re-index, cross-check and research in staging with no approval. `p-research` writes there. The user does not need to read it.

**Why it is not chosen:** The user said research goes into the staging of the topic it serves. Replaced by R12. Dropped 2026-10-23.

## R6. Consolidated is the current state

**Requirement:** A consolidated page says what is true now, not a history. The user confirms each page and gives it their confidence score, or marks it deferred.

**Why it is not chosen:** The user asked for a score on each heading, taken from the parent heading when not set. Replaced by R13. Dropped 2026-10-23.

## R11. Source records when it happened

**Requirement:** Source holds what happened, as it came in: a photo, a scan, an export, an OCR text, a fact the user tells. Each source file has the date of the real-world event, as an ISO date at the start of its name or of its folder's name. A check flags a source file with no event date. Media stay in iCloud through `media-icloud-sync`.

**Why it is not chosen:** The user said the event date is sometimes forgotten. Replaced by R14, which allows a month, a year, or `undated-`. Dropped 2026-10-23.

## R13. The user's confidence on each heading

**Requirement:** A consolidated page says what is true now, not a history. The user confirms it and gives a confidence score, or marks it deferred. A score can sit on any heading. A heading with no score takes the score of its parent heading. The root is the frontmatter, or the title if there is no frontmatter. A check flags a consolidated page with no score at its root.

**Why it is not chosen:** The user accepted git as the history and a dated "changed" line on a changed fact. Replaced by R15. Dropped 2026-10-23.

## R15. The user's confidence on each heading

**Requirement:** A consolidated page says what is true now. Git holds its history. When the user changes a confirmed fact, the page gets a dated "changed" line under that heading. The user confirms the page and gives a confidence score, or marks it deferred. A score can sit on any heading. A heading with no score takes the score of its parent heading. The root is the frontmatter, or the title if there is no frontmatter. A check flags a consolidated page with no score at its root.

**Why it is not chosen:** The user asked why a consolidated fact would be doubtful or deferred. Such a fact stays in staging, so the scale drops to 3 levels, with no "deferred". Replaced by R16. Dropped 2026-10-23.

## R17. A todo of missing information

**Requirement:** Each topic has a todo list of the information it misses, to gather or to make, each item with a priority. The user adds items, and Claude adds the gaps it finds: an `undated-` source, a fact with no source, a question research could not settle. Claude proposes a priority, and the user's priority wins. One command lists the open items of a whole KB, highest priority first.

**Why it is not chosen:** A separate todo file drifts away from the page it is about. A marker under the heading that misses the information keeps the two together, and `grep` collects all markers. The user left the choice to Claude. Replaced by R18. Dropped 2026-10-23.

## R10. A check for the suffix

**Requirement:** A check flags each KB file with no area suffix that is not a consolidated `.md`. A hook runs it on each write, and a script runs it over a whole KB.

**Why it is not chosen:** it is one of the checks of the shared script. Merged into R24. Dropped 2026-10-23.

## R14. Source records when it happened

**Requirement:** Source holds what happened, as it came in. Each source file has the date of the real-world event, as an ISO date at the start of its name or of its folder's name, or `YYYY-MM`, `YYYY`, or `undated-` with the day it came in. A check flags a source file with none of these, and lists the `undated-` files. Media stay in iCloud through `media-icloud-sync`.

**Why it is not chosen:** a fresh review found it too detailed: the date forms belong in the design. Replaced by R21. Dropped 2026-10-23.

## R16. The user's confidence on each heading

**Requirement:** A consolidated page says what is true now, and git holds its history, plus a dated "changed" line. The user gives a score: 3 checked against source, 2 sure, 1 likely. A doubtful fact stays in staging. A heading takes its parent's score, and the root is the frontmatter or the title. A check flags a page with no root score.

**Why it is not chosen:** too detailed, and it did not name the confirmed date that R19 reads. Replaced by R22, which names the date. The levels and the syntax went to the design. Dropped 2026-10-23.

## R18. Mark what is missing where it is missing

**Requirement:** A line `TODO(P1): <what is missing>` under its heading, P1 to P3. The user writes markers anywhere, Claude in staging only. One command lists every marker, P1 first.

**Why it is not chosen:** too detailed: the marker syntax went to the design. Replaced by R23. Dropped 2026-10-23.

## R19. Recheck on demand

**Requirement:** `/kb check` runs every rule over a whole KB with no LLM, and lists consolidated pages with an uncommitted change. `/kb recheck <topic>` has a fresh agent compare staging and new source against the consolidated pages, and writes a `TODO(P1)` per conflict.

**Why it is not chosen:** it named commands and read a `confirmed` date no requirement defined. Replaced by R25, with the date in R22. Dropped 2026-10-23.

## R20. One check, shared

**Requirement:** `kb-check.py` is the only holder of the KB file rules. The hooks of the `kb` skill, `p-research` and `p-sync-spec` call it. Each mode prints one line per problem and exits 1 on a problem.

**Why it is not chosen:** it called `p-sync-spec` a hook, and a listing such as the marks is not a problem. Replaced by R24, which also takes R10. Dropped 2026-10-23.

## R8. Skills know the layout

**Requirement:** One KB skill with hooks replaces `read-from-kb` and `trigger-kb-adoc`. `p-research` reads the KB by this layout, checks consolidated first, then researches online and compares.

**Why it is not chosen:** it named only `p-research`, and other skills also save KB files: the OCR, media, finance connector and claim skills. Replaced by R28. Dropped 2026-10-24.

## R26. Move today's files

**Requirement:** One move brings today's KB files into this layout. It renames each file together with its iCloud target, and fixes each link to it. The user sees a dry run first, and nothing moves without their yes. No page counts as confirmed until the user confirms it.

**Why it is not chosen:** The user said a move of every file is too much. The hooks start on a few folders and grow instead. Replaced by R27. Dropped 2026-10-24.
- **Grill of R30, 2026-11-20.** The detail check flagged the field names and scripts. They belong to the component `kb-object-model`, so R30 now names only the type and the relationships.
