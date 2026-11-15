# Findings: design

## State transitions

Model: [findings.qnt](findings.qnt), module `findings`. It runs once, from the transcript to a list. The page states are in `findings-page.qnt`, and the run states are in `session-retro.qnt` of the parent level.

```graph
import-graph: architecture.md
```

1. **Scan:** a script finds candidates and costs nothing (`scan`).
2. **Judge:** the fork of the session reads the candidates and returns the findings (`judge`).
3. **Findings JSON:** `findings.py check` keeps the real findings, and `findings-page.py` writes them (`check`).

## State deep dive

### Scan

`findings.py scan <transcript>` prints one JSON list of candidates, grouped by kind and subject. Each group has `kind`, `subject`, `count`, the `uuid` of its first event, and the `evidence` of that event, cut to 300 characters. The subject is the hook command, the first words of the guard text, the tool and its input, or the file. The scan sets it, so the same hook gives the same subject in each session.

A candidate before the last compaction entry gets `unseen: true`, because the fork sees only the context after it.

- Blocks (R7):
  - an attachment of type `hook_blocking_error`. Its `hookEvent` tells a Stop block from a tool block. The `stop_hook_summary` line is not read: it lists every Stop hook, not the one that blocked.
  - a tool result that starts `PreToolUse:<tool> hook error`, which is how a hook that denies a call shows.
  - a tool result that starts with a Claude Code guard text: the worktree guard, or the auto mode classifier.
  - a tool result with "doesn't want to proceed", and a `hook_non_blocking_error` for a failed hook.
- Loops (R2): the same tool with the same input, a Read of a file with no Edit or Write of it between, and an Edit whose new text is the old text of an earlier Edit of the same file. A call after an error result is not counted. A test command run again after an Edit is not counted.
- The user's messages (R3): each user text turn after an assistant reply, and "[Request interrupted by user]". The script only lists them. The model judges which ones are corrections.

- **Invariants:** none.
- **Expected output:** a list of candidate groups, empty when the transcript has none.

### Judge

The fork gets `references/findings-prompt.md`, the kinds of `references/findings-kinds.md`, and the candidates. It returns JSON only. For a block, it gives `right` (`yes`, `no`, `unknown`) and `avoidable` (`yes`, `no`), by the rule of R6. For an `unseen` candidate, it gives `right: unknown`. For a correction, it gives what the user said, how Claude read it, why, and a tip. A circle it finds itself takes the `uuid` of the nearest candidate or user turn in the list, as the prompt says. A kind not on the list is dropped by `findings.py check`.

- **Invariants:** none.
- **Expected output:** a JSON list of findings with `kind`, `uuid`, `subject`, `event`, `cause`, `change`, `tip`, and for a block `right` and `avoidable`.

### Findings JSON

`findings.py check` reads the fork's text and takes the JSON list out of it. Then:

- It drops a finding whose kind is not on the list, or whose `uuid` is not in the transcript.
- It adds back no candidate the fork left out (R8). A finding the fork adds, such as a circle, stays.
- For a candidate of the scan, found by `uuid` and kind, it keeps the scan's subject and count. It takes `unseen` from the candidate and ignores the fork's own `unseen` (R9). A block finding of an unseen candidate gets `right: unknown`.
- It sets each `id` from a short hash: of the kind and subject for a scan candidate, of the kind, `uuid` and subject for a finding the model added. A run again gives the same ID.
- It keeps the first finding of each `id` (R10).

- **Invariants:** `onlyListedKinds`, `uuidInTranscript`, `unseenIsUnknown`, `unseenFromScan`, `outFromFork`, `oneIdEach`.
- **Expected output:** the list `findings-page.py` writes.

## Build checks

Unit tests in `tests/skills/session-retro/test-findings.py`, run with `python3 -I`, on small transcripts the test writes.

| Test | Holds |
|---|---|
| each block shape gives one candidate of its kind | R7 |
| two blocks by one hook give one group with `count` 2 | R7 |
| a failed hook gives a `hook_failed` candidate | R7 |
| a candidate before a compaction entry is `unseen` | R6 |
| the same call twice gives `repeated_call`. A call after an error does not | R2 |
| a Read again with no Edit between gives `reread`. A Read after an Edit does not | R2 |
| an Edit back to the old text gives `undo_redo` | R2 |
| a test command run again after an Edit gives nothing | R2 |
| a user text turn after a reply is a `user_turn` candidate. A rejected call is a block, not a user turn | R3 |
| `check` drops a kind not in `findings-kinds.md`, and a `uuid` not in the transcript | `onlyListedKinds`, `uuidInTranscript`, `dropBadTest`, R4 |
| `check` sets `right: unknown` on a block of an unseen candidate, even if the fork wrote `yes` and `unseen: false` | `unseenIsUnknown`, `unseenFromScan`, `unseenTest`, `invariantsTest`, R6, R9 |
| a candidate the fork does not return is not in the list. A finding the fork adds stays | `outFromFork`, `dropCandidateTest`, R8 |
| two findings with one `id` give one finding, the first | `oneIdEach`, `oneIdTest`, R10 |
| `check` gives the same `id` to the same kind and subject in another order | R4 |
| `check` keeps the scan's subject over the model's | R7 |
| `check` takes the JSON list out of text around it | R4 |
| `findings-prompt.md` names the R6 rule: right, unknown, avoidable | R6 |

The negative control `checkKeepsAll` must fail. The state check is `C flow`.

No check can see if the model judged a block or a correction right. The user sees it on the page, and sets the status.

## Coverage

| Requirement | Held by |
|---|---|
| R7 | `tests/skills/session-retro/test-findings.py`, the block tests, `outFromFork` |
| R6 | `findings-prompt.md`, judged by the model, `unseenIsUnknown`, `unseenFromScan`, `unseenTest`. No script can judge the verdict |
| R2 | `tests/skills/session-retro/test-findings.py`, the loop tests. A circle the model finds takes the nearest listed `uuid` |
| R3 | `tests/skills/session-retro/test-findings.py`: the scan lists the user's turns. The model judges them |
| R8 | `tests/skills/session-retro/test-findings.py`: `check` adds no candidate back, `outFromFork`, `dropCandidateTest` |
| R9 | `tests/skills/session-retro/test-findings.py`: `check` reads `unseen` from the scan, `unseenFromScan`, `unseenTest` |
| R10 | `tests/skills/session-retro/test-findings.py`: `check` keeps the first of each `id`, `oneIdEach`, `oneIdTest` |
| findings_json | `dropBadTest`, `unseenTest`, `dropCandidateTest`, `oneIdTest`, `done` (a finished run stays as it ended, and only after `check`) |
| R4 | `tests/skills/session-retro/test-findings.py`, `findings-kinds.md`, `onlyListedKinds`, `uuidInTranscript`, `dropBadTest` |

## Risks

- **The transcript format is internal.** A new Claude Code version can rename a field. The scan reads `version`, and a test fixture per shape shows what broke.
- **Too many candidates.** A long session had 363 guard blocks. The groups of the scan keep the prompt small.
- **The model invents a finding.** `check` drops a finding whose `uuid` is not in the transcript.

## Appendix

- Q1 to Q5 of `transcript-signals.staging.md` in `personal`: the block shapes, counts, and the loop scan this design copies.
- Q4 of `anthropic-features.staging.md`: how `/insights` splits a script layer from a model layer, with a fixed list of names.
