# Findings page: design

## State transitions

Model: [findings-page.qnt](findings-page.qnt), module `findingsPage`.

```graph
import-graph: architecture.md
```

1. **None:** the session has no page yet.
2. **Cold:** the retro wrote a one-line page, with no findings.
3. **Full:** the retro read the transcript and wrote each finding with its status.

`findings-page.py` makes each move. It reads the findings as JSON and merges them into the page. It writes the page in `~/.claude/session-retro/pending/` first, and moves it into `personal` only when no secret pattern matches (`moveIn`). The commit script commits only a page in `personal` (`commit`).

## State deep dive

### None

No page in `claude-research/session-retro/` of `personal` ends in `-<first 8 characters of the session ID>.staging.md`. The script finds a page by that ending, so a run on a later date finds the same page. A new page takes the date of the first transcript entry.

- **Invariants:** none.
- **Expected output:** none. A run moves to Cold or Full (`runCold`, `runFull`).

### Cold

The retro found that the last transcript entry is more than an hour old. `findings-page.py cold` writes one line that says why, and no findings. It never writes over a Full page: `runCold` has the guard that the page is none or cold.

- **Invariants:** `coldHasNoFindings`, `fullStaysFull`.
- **Expected output:** a page with a title, the session ID, and one line: "Not read: the last transcript entry is <n> minutes old."

### Full

`findings-page.py full` writes each finding as a `###` heading with its ID, then lines for kind, status, count, session ID and transcript `uuid`. If the page exists, it reads each status line first:

- A finding that was on the page keeps its status. A new finding is `open` (`runFull`).
- The ID comes from `findings.py check`, so the same finding gets the same ID on each run.
- Only the user changes a status, by an edit of the page (`userSets`). The page says so above the first finding.
- A session with no findings gets the line "No findings."

Then `findings-page.py move` runs the secret check. A clean page moves into `personal` (`moveIn`). A page that matches goes to `~/.claude/session-retro/rejected/`, and never enters the KB. `commit-page.sh` runs the secret check and `kb-check.py` again on the page in `personal`, then commits it (`commit`).

- **Invariants:** `fullStaysFull`, `onlyUserSets`, `kbHasNoSecret`.
- **Expected output:** the page, with each finding open or with the status the user gave it.

## Build checks

Unit tests in `tests/skills/session-retro/test-findings-page.py`, run with `python3 -I`. Each builds pages in a temp folder.

| Test | Holds |
|---|---|
| a cold run on no page writes one line | `runCold`, `coldHasNoFindings` |
| a cold run on a full page leaves it as it was | `fullStaysFull` |
| a full run on a cold page writes the findings | `runFull` |
| a run again keeps `confirmed` and `dropped`, adds new findings as `open` | `runFull`, `onlyUserSets` |
| a run again on a later date finds the page by the session ID | `runFull` |
| the retro's JSON with a status other than `open` is written as `open` | `onlyUserSets` |
| `move` puts a page with a token, an AWS key ID or a JSON-escaped secret field in `rejected/`, not in the KB | `moveIn`, `kbHasNoSecret` |
| `move` puts a clean page in the KB | `moveIn` |
| a session with no findings gets "No findings." | `runFull` |
| `confirmed` lists the confirmed findings of all pages | R6 |
| `summary` counts open findings over all pages, and names a kind and subject in 2 sessions | the reminder of `session-retro` |

The model runs `secretPageStaysOutTest`, `cleanPageCommittedTest`, `coldAfterFullFailsTest`, `rerunKeepsStatusTest` and `onlyUserSetsTest` give the traces for the fixtures of these tests.

`done` is the move of a finished page. The negative control `allStayOpen` must fail in the model run: The user confirms a finding, so not every finding stays open.

No check can see that the user, and not the retro, set a status. The test shows that the retro never writes one.

## Coverage

| Requirement | Held by |
|---|---|
| full | `rerunKeepsStatusTest` |
| R7 | `runFull`, `runCold`, `fullStaysFull`, `coldHasNoFindings` |
| R2 | `moveIn`, `commit`, `kbHasNoSecret` |
| R5 | `userSets`, `onlyUserSets` |
| R6 | a list in `findings-page.py confirmed`, not in the model: this build makes no move, so there is no state |

The page name, the `kb` layout and the links to the session ID and `uuid` are text, not states. The unit tests and `kb-check.py` check them.

## Risks

- **A secret pattern misses a secret.** The patterns come from Q5 of `transcript-signals.staging.md`, with a positive control for each. A miss reaches a private repo, not the web. The user can add a pattern to the script.
- **A pattern refuses a clean page.** The page stays in `rejected/`, and the failure log names the pattern. The reminder shows it.
- **The user edits a heading.** The merge matches findings by ID in the heading. A finding with a changed ID counts as new and comes back `open`. The page tells the user to change only the status line.
- **Two runs at once on one session.** `retro.sh` holds a lock per session, so a second run waits for the first.

## Appendix

- Q5 of `transcript-signals.staging.md` (`personal`, `claude-research/staging/2026-10-24-session-retro/`): the secret patterns and their counts.
- Q3 of `trigger-and-run.staging.md`: the domain and page name.
- Model checks, from the harness root:

  ```sh
  npx quint test plans/session-retro/components/findings-page/findings-page.qnt --main=findingsPage
  npx quint run plans/session-retro/components/findings-page/findings-page.qnt --main=findingsPage --invariant=allStayOpen   # must report a violation
  ```
