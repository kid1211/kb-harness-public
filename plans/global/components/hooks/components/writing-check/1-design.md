# Writing check: design

## State transitions

Model: [writing-check.qnt](writing-check.qnt), module `writingCheck`. One run of `.claude/hooks/writing-check.py`, as a hook (`post`, `stop`) or as a command (`file`, `report`).

```graph
import-graph: architecture.md
```

1. **received**: the script starts with its command. A hook has its input on stdin. [Deep dive](#received)
2. **loaded**: the rules file holds its four tables. [Deep dive](#loaded)
3. **checked**: the command is `post`, `stop` or `file`, and each rule has its score. [Deep dive](#checked)
4. **quiet**: a hook in mode `off`, or a `post` on a path it skips. [Deep dive](#quiet)
5. **fed_back**: a checked run ends. [Deep dive](#fed_back)
6. **reported**: the command is `report`. [Deep dive](#reported)
7. **failed_open**: a hook cannot read the rules file. [Deep dive](#failed_open)
8. **failed**: a command cannot read the rules file. [Deep dive](#failed)

## State deep dive

### received

The script reads its command. `post` and `stop` read the hook JSON on stdin and the mode of `~/.claude/writing-check-mode.json`. No mode file reads as `pro`. The skip check comes first, before the script reads the rules file: mode `off`, a `post` on a non-`.md` file, on raw research or on a file with the off mark, and a `stop` with `stop_hook_active`. So a stop blocks once at most. The read of the rules file moves inside the `try` of the hooks.

**Moves:** `skip` to quiet, `load` to loaded, `failOpen` to failed_open, `failCmd` to failed.

**Invariants:** `noModeIsPro`, `offIsQuiet`, `skipIsQuiet`, `stopBlocksOnce`.

**Expected output:** none yet.

### loaded

The script reads the four word tables of `.claude/hooks/writing-rules.md`, under `### Words not to use`, `### Phrases not to use`, `### Weak words` and `### AI tells`. It reads the Terms table of `.claude/CLAUDE.md` only if that file is there. Else `checkedTerms` and `otherTerms` have no words and pass. It reads the STE data of `~/.claude/ste100/` only if it is there. Else `steWords` passes.

**Moves:** `report` to reported, `check` to checked.

**Invariants:** `termsOptional`, `steOptional`.

**Expected output:** none yet.

### checked

Each rule scores the text. A `post` with a chart signal (a table, a prose signal or a data mention) asks `chart-suggest` for a chart note. `steWords` scores and logs in each mode, with a threshold of 0 in casual. With no catalog page, there is no note.

**Moves:** `feedBack` to fed_back.

**Invariants:** `catalogOptional`.

**Expected output:** the scores.

### quiet

The hook exits 0 and prints nothing. Each end state stays as it is by the move `done`.

**Invariants:** `hookExitsZero`, `offIsQuiet`, `skipIsQuiet`.

**Expected output:** exit 0, empty stdout.

### fed_back

- `post`: if a rule fails, stdout holds a block JSON that lists the failures and names the file of each failed rule: `.claude/hooks/writing-rules.md`, or `.claude/CLAUDE.md` for a term rule. The edit stays. A chart note alone goes as `additionalContext`: advice, not a block.
- `stop`: the run is logged. Only a short path blocks the stop once, with the same message.
- `file`: prints the result, and exits 1 if a rule fails. `fullPaths` does not run on a file.

**Invariants:** `hookExitsZero`, `replyBlocksOnlyForPaths`, `editFeedback`, `messageNamesRules`, `noteIsAdvice`, `fileIgnoresPaths`.

**Expected output:** exit 0 for a hook. The block JSON, or nothing.

### reported

The report prints each rule, its pro and casual threshold, the speed, and the log of the session and the week.

**Invariants:** `reportNeedsOnlyRules`.

**Expected output:** exit 0, the report on stdout, nothing on stderr. In the public clone, with only the rules file, too. The runs start the public clone by `initPublic`.

### failed_open

A hook that cannot read the rules file prints `writing-check: <error>` on stderr and exits 0. The session goes on.

**Invariants:** `hookExitsZero`.

**Expected output:** exit 0, one stderr line, empty stdout.

### failed

`report` or `file` with no rules file prints the error and exits 1. The config pane shows that line.

**Invariants:** none beyond the model's moves.

**Expected output:** exit 1, one stderr line.

## Build checks

Unit tests in `writing-check.py --test`, one per invariant and expected output:

- `hookExitsZero`, `failed_open`: `post` and `stop` with a missing rules file exit 0 with one stderr line.
- `termsOptional`: with no `.claude/CLAUDE.md`, the term rules pass and nothing fails.
- `steOptional`, `catalogOptional`: no STE file, no catalog: `steWords` passes, no chart note. The tests of these exist and stay.
- `reportNeedsOnlyRules`, `initPublic`: `report` in a throwaway folder that holds only the script and the rules file, with an empty `HOME`, exits 0 with an empty stderr.
- `messageNamesRules`: each block message names the file of each failed rule.
- `stopBlocksOnce`, `noteIsAdvice`, `fileIgnoresPaths`: a stop with `stop_hook_active` is quiet, a chart note alone is `additionalContext`, a short path in `file` passes. The tests of these exist and stay.
- `replyBlocksOnlyForPaths`, `editFeedback`, `noModeIsPro`, `offIsQuiet`, `skipIsQuiet`: the tests of these exist and stay.
- The release: the name scan and the PII scan of `scripts/public-release/scan.sh` pass on the script, the rules file, this level and `tests/e2e/writing-check/` (R20).
- The e2e test `tests/e2e/writing-check/`: in a fresh clone of the public `nightly`, the config pane shows the report, and a `.md` edit with a banned word gets feedback (R17).

No check sees whether a public session reads the rules as instructions: nothing loads them there (R18).

## Coverage

| Requirement | Held by |
|---|---|
| R1 | `replyBlocksOnlyForPaths`, run `replyLoggedTest` |
| R2 | `editFeedback`, run `publicEditTest` |
| R3 | `hookExitsZero`, `stopBlocksOnce`, runs `brokenRulesHookTest` and `stopOnceTest` |
| R4 | Not in the model: how a rule scores. The unit tests of each rule |
| R6 | Not in the model: the parse of prose. The unit tests |
| R7 | Not in the model: the log line. The unit tests |
| R8 | Not in the model: speed. The report prints it |
| R9 | `noModeIsPro`, `offIsQuiet`, run `offQuietTest` |
| R10 | `skipIsQuiet` |
| R11 | `reportNeedsOnlyRules`, run `publicReportTest` |
| R12 | `replyBlocksOnlyForPaths`, `fileIgnoresPaths`, run `publicReplyPathTest` |
| R13 | `catalogOptional`, `noteIsAdvice`, run `privateChartTest`. The rule text stays in `.claude/CLAUDE.md` |
| R17 | Not in the model: the release list. The e2e test and the release checks |
| R18 | `messageNamesRules`, `termsOptional`, the move `load` |
| R19 | `termsOptional`, `steOptional`, `catalogOptional`, `reportNeedsOnlyRules` |
| R20 | Not in the model: text. The name scan of the release |
| quiet | the end of the run: the run `offQuietTest` |
| fed_back | the end of the run: the run `publicEditTest` |
| reported | the end of the run: the run `publicReportTest` |
| failed_open | the end of the run: the run `brokenRulesHookTest` |
| failed | the end of the run: the run `reportNoRulesTest` |

## Risks

- **The `@` import does not load in a KB.** `.claude/CLAUDE.md` is a link in each KB, and so is `.claude/hooks`. The import path `hooks/writing-rules.md` resolves the same from the link or from its target. The build checks it in a KB session.
- **A rule table goes missing from the rules file.** `table()` raises on a missing heading. The hook fails open, and `report` fails with a line that names the file.
- **The Terms table and the rules file drift apart.** They hold different tables, so no row is in both.
- **The chart note names a private path.** Its text names the catalog page of the `personal` KB. With no catalog there is no note, so the public clone never shows it. The build takes the name out of the text by R20.
- **A public user gets a Stop check by default.** No mode file reads as `pro`, as in the private harness. The `writing-mode` buttons switch it off.

## Appendix

- The release filter of hooks: `scripts/public-release/scan.py`, `settings` mode, which keeps a hook whose script is listed (`public-release/R54`).
- The name scan: `bash scripts/public-release/scan.sh names <dir>` on a copy of the files.
