# Chart suggest: design

## State transitions

The model is [chartSuggest.qnt](chartSuggest.qnt), module `chartSuggest`.

```graph
import-graph: architecture.md
```

1. [Edit](#edit): a markdown edit passes the checks of `writing-check`.
2. [Missing](#missing): the catalog page is gone. The check logs it once and suggests nothing.
3. [Read signals](#read_signals): the check reads the signal table of the catalog page.
4. [Scan](#scan): the check reads what the edit adds, and counts the rows that match.
5. [Note](#note): Claude gets one line for each match.
6. [Done](#done): the edit goes on.

## State deep dive

### Edit

The `catalog_script` node is `scripts/chart-catalog.py`: it reads the same page and is no state of the note. `writing-check` calls the chart rule for a markdown edit that its R2 checks. The rule stops here if the docs mode is `off` or the file is the catalog page. Replies get no chart note. `editSkipped`, `editNoCatalog` and `editReads` are the three moves out of this state. `missingEnds` and `readDone` leave Missing and Read signals.

**Invariants:** `noteNeverBlocks`

**Expected output:** nothing yet.

### Missing

The catalog page is `chart-catalog.staging.md` in the `personal` KB. If it does not exist, the check writes one line in the log and touches a marker file, so the next edit does not log again. `missingEnds` goes to Done. The marker goes when the page is back.

**Invariants:** `missingLoggedOnce`

**Expected output:** one `chart/missing` log line, and no note.

### Read signals

`chart_signals` reads the signal table: one row per signal, with its test, its form and its reason. A change to the page changes the check. `readDone` goes to Scan.

**Invariants:** `noteNeedsMatch`

**Expected output:** a map from signal to form and reason.

### Scan

`chart_notes` reads the added text. It skips code. It reads the tables, the `csv` and `tsv` blocks, and the `.csv`, `.tsv` and `.xlsx` files that the text links to. It skips a linked file that is missing, large or only in iCloud, and never downloads it. Words in the text match only with a number. A text that names data it does not hold, such as "the CSV", gets a note with no form. `scanDone` counts the matches.

**Invariants:** `noteNeedsMatch`

**Expected output:** a list of lines, one for each match.

### Note

`noteSent` sends the lines as extra context for Claude, headed "Chart note (advice, not a failure)". When the edit also fails a scored rule, the note rides in the same message. It is never a reason to block.

**Invariants:** `noteNeverBlocks`, `noteNeedsMatch`

**Expected output:** a `chart/note` log line, and the note text.

### Done

The edit goes on. `keep` leaves every variable as it is, for the asserts of the runs.

**Invariants:** `noteNeverBlocks`, `missingLoggedOnce`

**Expected output:** exit 0 for the chart rule.

## Build checks

- The model action `ended` keeps an ended run as it is, so `quint verify` finds no deadlock. It is no state or move of the graph.

Unit tests, no LLM eval:

- `python3 -I .claude/hooks/writing-check.py --test`: the chart cases. A date trend, a grid, a limit, a share, words with and without a number, code skipped, a `csv` block, a linked `.csv` and `.xlsx`, a missing, large or iCloud-only file, no catalog, and a note that rides in a block. It serves `noteNeverBlocks`, `missingLoggedOnce`, `noteNeedsMatch`.
- `python3 -I scripts/chart-catalog.py --test` (the `catalog_script` node): the forms of `dataviz` against the catalog rows, new and missing (R4).
- `npx quint test plans/global/components/hooks/components/writing-check/components/chart-suggest/chartSuggest.qnt --main=chartSuggest`: one `run` for the note, the quiet edit, the missing page and the mode off.
- `keep` leaves every variable as it is, for the asserts of the runs.
- No check sees R1, R2, R3 and R6: they are the catalog page and its research, which the user confirms.

## Coverage

| Requirement | Where it is held |
|---|---|
| R1 | not in the model: the catalog page, which the user confirms. `chart-catalog.py --test` finds a row that `dataviz` does not name |
| R2 | not in the model: the rule of the scores is text on the catalog page, which the user confirms |
| R3 | not in the model: text on the catalog page. `chart-catalog.py --test` finds `dataviz` |
| R4 | the `catalog_script` node of the graph, and `chart-catalog.py --test`. The script is no state of the note |
| R5 | `noteNeverBlocks`, `missingLoggedOnce`, `editSkipped`, `editNoCatalog`, `noteSent`, `notedTest`, `missingTest`, `offTest`, `writing-check.py --test` |
| R6 | not in the model: research, answered in the staging page. The model holds its answer, a table read and no LLM |
| R7 | `noteNeedsMatch`, `editReads`, `readDone`, `scanDone`, `quietTest`, `writing-check.py --test` |
| R9 | `scanDone`, the file cases of `writing-check.py --test` |
| done | the end of the rule: `notedTest`, `quietTest`, `missingTest`, `offTest` |

## Risks

- A signal test reads a table of any shape, so a wrong note can appear. It is advice, and Claude decides.
- The catalog page sits in the `personal` KB. A machine without that KB logs the missing page once and gives no note.
- The scan reads files by link. A large file is skipped, so a big data set gets no note.

## Appendix

- Research: `personal/claude-research/staging/2026-10-25-chart-suggest/detect-chart-need.staging.md`.
- Run the model: `npx quint run plans/global/components/hooks/components/writing-check/components/chart-suggest/chartSuggest.qnt --main=chartSuggest --invariant=allInvariants`.
