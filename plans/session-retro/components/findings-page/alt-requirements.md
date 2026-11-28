# Findings page: dropped requirements and closed questions

## R1. One page per session

**Requirement:** The retro writes one staging page per session in a domain of the `personal` KB, by the `kb` skill. Each finding links to the session ID and its place in the transcript. If the retro runs again on the same session, it updates the same page.

**Why it is not chosen:** the user chose the domain: `claude-research/session-retro/`. R4 names it. Dropped 2026-10-24.

## R3. Open until the user decides

**Requirement:** Each finding is open until the user confirms or drops it. A finding moves out of staging only after the user confirms it.

**Why it is not chosen:** a fresh check found two ideas in it: the status of a finding, and when it moves. R5 and R6 take its place. Dropped 2026-10-24.

## R4. One page per session

**Requirement:** The retro writes one staging page per session in `claude-research/session-retro/` of the `personal` KB, by the `kb` skill. Its name is `<date>-<first 8 characters of the session ID>.staging.md`. Each finding links to the session ID and the `uuid` of its transcript line. A session with no findings gets a page that says so.
  - If the retro runs again on the same session, it updates the same page. It keeps the status of each finding, and it never puts a one-line cold page in place of a full page.

**Why it is not chosen:** a fresh check of the design found two holes. Rule 1 of the `kb` skill says Claude writes KB files with Write or Edit, but a script writes this page. And a name with the date of the run gives a second page when the retro runs again on a later day. R7 fixes both. Dropped 2026-10-24.
