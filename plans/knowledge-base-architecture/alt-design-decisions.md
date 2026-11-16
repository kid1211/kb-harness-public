# Knowledge base architecture: designs not chosen

## Three folders per area

`source/`, `staging/` and consolidated pages in folders of each domain or topic. A hook reads the area from the path.

**Not chosen:** The user found folders too much, and wanted the three areas side by side in one topic folder. A dot suffix gives the hook the same signal. 2026-10-23.

## A `kb-` prefix and a `wip-` prefix

Keep `kb-` for consolidated pages, add a prefix for staging, and leave source unmarked.

**Not chosen:** a missing prefix silently makes a page source. With a suffix, a missing suffix makes a page consolidated, and the hook asks the user. 2026-10-23.

## The area in frontmatter

A field such as `area: staging` in each page.

**Not chosen:** a photo or a PDF has no frontmatter, and the hook must open each file to read it. Frontmatter holds only the root score and its date. 2026-10-23.

## The score in an HTML comment

`## Medications <!-- confidence: 2 -->`, drawn as a ring by the VS Code extension.

**Not chosen:** the comment is hidden in the preview until the extension changes, and in any other viewer. A plain `Confidence:` line shows everywhere. A ring from the kitchen sink (R4, numbers) can be added later on top of the plain line. 2026-10-23.

## A score in the heading text

`## Medications (2)`.

**Not chosen:** the score becomes part of the heading's anchor, so a link to the heading breaks when the score changes. 2026-10-23.

## A five-level score with "deferred"

5 checked and sure, 4 sure, 3 likely, 2 doubtful, 1 likely wrong, and "deferred".

**Not chosen:** The user asked why a consolidated fact would be doubtful or deferred. Such a fact stays in staging. 2026-10-23.

## A todo file per topic

`todo.staging.md` in each topic folder.

**Not chosen:** a separate file drifts from the page it is about. A `TODO(Pn)` line under the heading keeps the gap where it is. 2026-10-23.

## A conflict queue file

One file of open conflicts, with a count at session start.

**Not chosen:** a conflict is a `TODO(P1)` marker in staging, so `kb-check.py todo` lists conflicts with the other gaps, P1 first. One list, not two. 2026-10-23.

## The hook denies every consolidated write

`deny` with a reason, so Claude must ask the user in the reply and try again.

**Not chosen:** `ask` puts the yes in the user's permission prompt, and the docs say it prompts in auto mode. `deny` stays the fallback if a test shows `ask` does not prompt in another mode. 2026-10-23.

## Check a consolidated page after the write

The hook asks the user first. The PostToolUse hook then runs `kb-check.py`, and Claude fixes a missing score or source.

**Not chosen:** the page is already changed when the check finds the gap, and the model said such a write is refused. The guard now builds the page as it will be and checks it before the user is asked. A fresh review found the gap. 2026-10-23.

## Leave the Bash write out of the model

The model covered Write and Edit only, and Risks named the Bash write.

**Not chosen:** the main risk had no state, so no invariant said what happens. The model now has a `flagged` state for it. 2026-10-23.

## A one-time move of today's files

Replaced (2026-11-02). Before: `kb-migrate.py` renamed every file with its iCloud target, rewrote each link, and ran a dry run first. Row R26 and the component `migrate` held it. R27 replaced it: no move, and the hooks act only on the folders in a list.
