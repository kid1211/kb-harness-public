# Spec rounds: design

## State transitions

Model: [spec-rounds.qnt](spec-rounds.qnt), module `specRounds`.

```graph
import-graph: architecture.md
```

1. **Start:** `retro.sh` has moved the page into the KB. It calls `spec-rounds.py record <session> <transcript> <page>`. [Deep dive](#start)
2. **Scanned:** the script found the rounds of the session in its transcript. [Deep dive](#scanned)
3. **Skipped:** the session ran no round. [Deep dive](#skipped)
4. **Written:** the rows and the Spec section are in place. [Deep dive](#written)
5. **Recorded:** `commit-page.sh` commits the page and `spec-rounds.csv`. [Deep dive](#recorded)
6. **Failed:** the run logged its error, and the page goes in as it was. [Deep dive](#failed)

## State deep dive

### Start

`retro.sh` calls the script after `findings-page.py move`, for a cold page and a full page alike. The script reads only the transcript and the CSV. It runs no model.

- **Invariants:** `otherRowsKept`.
- **Expected output:** none yet.

### Scanned

A round ends at each Bash call whose command holds a commit message that starts `[automatic after <skill>] <level>:` and whose result is not an error. The round runs from the end of the round before, or from the first prompt of the session. For each round the script counts, from the records in that span:

- Claude minutes: the sum of the `turn_duration` records. Minutes waiting on the user: each `AskUserQuestion` call to its result. Model minutes and tool minutes: the time from each call to its result, split by kind, as `rounds.py` of `spec-performance` does.
- Subagents: each `Agent` call, and the minutes from the call to its result. Turns: the assistant records.
- Failures: Stop-hook blocks by the hook name before the first `:` of the block text, such as `writing-check:2`. Failed checks: a Bash result with `is_error` whose command runs a test or a check. Rejected tool calls: a result that says the user does not want to proceed. Interrupts: a prompt that starts `[Request interrupted by user`.
- The user's prompts by kind, by keyword: status, confused, continue, skip-checks. A prompt can be of no kind.

The model finds any count of rounds by `scan`, through `scanTo`. A run again finds the same rounds.

- **Invariants:** none.
- **Expected output:** a list of rounds in memory.

### Skipped

No round: the script writes no row and no section, and prints `skipped for now: no spec round`. If the skill has no `spec-rounds.py`, as in an older release, `retro.sh` logs `spec rounds: skipped for now` and runs no script. Either way the page is the same as before the spec rounds.

- **Invariants:** `sectionIffRounds`.
- **Expected output:** the CSV and the page as they were.

### Written

1. Read `claude-research/session-retro/spec-rounds.csv` of the KB, or start it with its header. Drop each row of this session. Add one row per round, with `source` set to `retro`. Write the file again, sorted by end time.
2. On the page, take the place of the `## Spec` section, or add it at the end. It holds one line of rounds and levels, then a table: metric, this session (median per round), all rows (median per round), and `worse` where this session is above the median. Each metric in the table is one where more is worse.

- **Invariants:** `oneRowPerRound`, `sectionHasRows`, `otherRowsKept`.
- **Expected output:** the CSV with one row per round of this session. The page with one `## Spec` section.

### Recorded

`commit-page.sh` takes the page and the CSV, and commits them in one commit (`record`). After it the run stays as it is (`done`).

- **Invariants:** `sectionIffRounds`.
- **Expected output:** one KB commit with both files.

### Failed

No transcript (`noTranscript`), or an error while it writes (`writeFails`). The script exits 1 and writes nothing. `retro.sh` logs the error to `failures.log` and goes on to commit the page.

- **Invariants:** `otherRowsKept`.
- **Expected output:** a line in `failures.log`. The CSV and the page as they were.

## Build checks

Unit tests in `tests/skills/session-retro/test-spec-rounds.py`, in the form of `test-findings-page.py` next to it, each on a made-up transcript and a throwaway KB:

| Test | Checks |
|---|---|
| two rounds | two rows, each count right, `oneRowPerRound`, a Spec section |
| run again | the same rows and one section, `oneRowPerRound` |
| other session | its rows stay, `otherRowsKept` |
| no round | no row, no section, `sectionIffRounds` |
| no transcript | exit 1, nothing written |
| worse mark | `worse` only where this session is above the median |
| section with rows | a page with a Spec section has rows of its session, `sectionHasRows` |

Run: `python3 -I tests/skills/session-retro/test-spec-rounds.py`.

The model runs `recordedTest`, `skippedTest`, `failedTest` and `againTest`. The checker must find a violation of the negative control `neverSkipped`, since the script skips a session with no automatic plan commit.

## Coverage

| Want | Holds it |
|---|---|
| F1 | `writeRows`, `oneRowPerRound`, `otherRowsKept`, tests "two rounds", "run again", "other session" |
| F2 | not in the model: the counts of Scanned, test "two rounds" |
| F3 | not in the model: the keyword kinds of Scanned, test "two rounds" |
| F4 | `skip`, `sectionIffRounds`, `sectionHasRows`, tests "no round", "worse mark", "section with rows" |
| F5 | `skip`, tests "no round" and `spec_rounds_missing_skips` of `test-session-retro.sh` |
| recorded | `recordedTest`, `record` |
| skipped | `skippedTest`, `skip` |
| failed | `failedTest`, `noTranscript`, `writeFails` |

## Risks

- A keyword sort of the user's prompts misses some and catches others. The kinds are a trend, not a count to trust one by one.
- A round of a session that commits nothing has no end, so its work counts in the next round, or nowhere.
- `commit-page.sh` must take the CSV too. It is on the `Builds:` line.

## Appendix

- The method: `claude-research/spec-performance/scripts/rounds.py` of the `personal` KB, run on 2026-11-28 over 799 rounds.
- The numbers it gave: the follow-up section of `claude-research/spec-performance/spec-performance.staging.md` of the `personal` KB.
