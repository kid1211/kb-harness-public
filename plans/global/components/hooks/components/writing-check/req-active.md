# Writing check: detailed requirements

## Requirements

- ✅ **R1. Check each reply:** when Claude stops, a `Stop` hook checks the text of the last reply. That is the text after the last tool call. The hook logs the result and prints nothing. It does not block the stop, because a Stop message shows to the user and `/focus` does not hide it. *(the user, 2026-10-23. Until then the hook blocked the stop once and Claude wrote the reply again.)*
  - Serves: F1
- ✅ **R2. Check each markdown edit:** after a Write, Edit or MultiEdit of a `.md` file, a `PostToolUse` hook checks only the text the edit adds. If a rule fails, the hook gives the failures to Claude, who fixes the file. Old text is not checked. *(the user, 2026-10-23)*
  - Serves: F1
- ✅ **R3. Feedback only:** the hooks return a message and nothing else. They do not undo a write. A reply is blocked once at most, so a reply that fails twice ends as it is. *(the user, 2026-10-23)*
  - Serves: F1
- ✅ **R4. Rules and thresholds:** each rule scores the share of sentences that pass. A rule fails when its score is under its threshold. Each threshold is one number at the top of the script. *(the user, 2026-10-23)*
  - Serves: F3

  | Rule | A sentence passes when | Threshold |
  |---|---|---|
  | `length` | it has 20 words or fewer for a numbered step, 25 for any other | 80% |
  | `bannedWords` | it has no word from "Words not to use" | 100% |
  | `checkedTerms` | it has no word from the "Never call it" column of the terms table | 100% |
  | `filler` | it has no phrase from "Phrases not to use" | 100% |
  | `paragraphs` | (per paragraph) a plain paragraph has 3 sentences or fewer, so more becomes a list | 80% |
  | `weakWords` | it has no word from "Weak words" | 80% |
  | `passive` | it has no form of "be" plus a participle, such as "was removed" | 80% |
  | `repeatedWord` | it has no word twice in a row, such as "the the" | 100% |
  | `readability` | (whole text, 30 words or more) Flesch reading ease is 50 or more | 50 |
  | `semicolons` | it has no `;` | 100% |
  | `dashes` | it has no `—` and no ` -- ` | 80% |
  | `emoji` | it has no emoji. A status emoji that starts a list item, or one in a table, is not counted | 80% |
  | `otherTerms` | it has no word from "Do not call it, in this sense" | 50% |
  | `aiTells` | it has no word or opener from "AI tells", such as "delve" or "Certainly!" | 100%, casual too |
  | `contractions` | (whole text) the share of "don't" over "do not" and the like. No pair scores 1 | casual only, 60% |
  | `rhythm` | (whole text, 5 sentences or more) the spread of sentence lengths, standard deviation / mean | casual only, 0.35 |
  | `person` | (whole text, 30 words or more) it has "I", "you" or "we" | casual only |
  | `fullPaths` | (per path, replies only) a code or `.md` file path starts with `/` or `~/` (R12) | 100%, casual too |
  | `steWords` | it has no word that the ASD-STE100 Issue 9 dictionary only rejects. The data file is in `~/.claude/ste100/`, out of the repo | 20%, casual off |

  - Why only 20% for `steWords`: 33 replies of the session that built it had a median of 45%. Most hits were normal engineering words such as "run", "file" and "now". The STE list is for aircraft manuals. At 20%, the worst 6 of 33 fail. Raise it as replies improve.
  - Why 50% for `otherTerms`: at 80%, it failed 4 of the 6 replies of the session that built it. "Rule", "section" and "command" are often the right word.
- 🚀 **R18. One rules file:** [implement] the writing rules that ship sit in `.claude/hooks/writing-rules.md`: the four word tables, under `### Words not to use`, `### Phrases not to use`, `### Weak words` and `### AI tells`, then the sentence rules and the file path rule. `.claude/CLAUDE.md` loads it with an `@` import. The script reads those tables from that file only. Each message names the file of the rule that failed. *(the user, 2026-11-23)*
  - Serves: F1, F5
  - Design input: the Terms table stays in `.claude/CLAUDE.md`, since it holds this harness's own words, and `id-hover` and `term-scan.py` read it there. The script reads it there if the file exists.
  - Design input: a public session gets the hook feedback only. Nothing in the public clone loads the rules file as instructions.
- ✅ **R6. Not prose:** code blocks, table rows and headings are not checked. A code span or a quote counts as one word. A quote mentions a word, it does not use it. *(the user, 2026-10-23)*
  - Serves: F4
- ✅ **R7. A log to tune the thresholds:** each check adds one line to `~/.claude/writing-check.jsonl`: the time, reply or file, and the score of each rule. the user or Claude reads it to raise or lower a threshold. *(the user, 2026-10-23)*
  - Serves: F3

- ✅ **R8. Quick, no LLM:** each check is a local script that runs in under a second. No check calls an LLM, such as a `prompt` hook. A check by a model is added only if one already runs here for another job. *(the user, 2026-10-23)*
  - Serves: F1

- ✅ **R9. Modes for replies and docs:** two buttons above the prompt set the mode of replies and of docs, each one of `off`, `casual` or `pro`. A press moves to the next mode. The mode lives in `~/.claude/writing-check-mode.json`, so it holds for every session. No file means `pro`. *(the user, 2026-10-23)*
  - `off`: the hook does not check.
  - `pro`: the full thresholds of R4.
  - `casual`: only the bans stay (words, terms, filler, repeated words), with dashes and paragraphs at 80%, weak words and readability at 60%. Emoji are allowed. A section in the system prompt tells Claude to write like an engineer talking to a friend, with at most one emoji and one light joke per reply, and no joke about bad news, health or money.
  - The buttons are a Claude Code mod, `writing-mode`, in `.claude/skills/writing-mode/`. Claude Code loads a plugin from the project's `.claude/skills/<name>/`, so it loads in the harness and in each KB, whose `.claude/skills` links to the harness.
  - The mode file, the log and the STE data stay in `~/.claude/`, per machine. `writing-check.py ste-setup` gets the STE data.
  - Serves: F2
- ✅ **R10. Text that must stay as it is:** the hook skips any path with `raw-deep-research/` in it, and any file with the line `<!-- writing-check: off -->`. *(the user, 2026-10-23)*
  - Serves: F4

- ✅ **R11. A report to tune from:** `writing-check.py report` prints each rule with its pro and casual threshold, the speed at 100, 1,000 and 10,000 words, and, for this session and for the last 7 days of the log, the median, the mean and the fail rate of each rule, plus the rejected STE words used most with the words to use instead. The `writing-mode` mod shows it in a pane, from `/writing-check` or a dim `⚙ config` button at the right of the band. The pane has a Refresh button. *(the user, 2026-10-23)*
  - Serves: F3

- ✅ **R12. Full file paths in a reply:** each path to a code or `.md` file in a reply starts with `/` or `~/`, as "File paths in a reply" in `.claude/CLAUDE.md` asks. the user opens a path with ⌘-click in cmux. cmux reads a short path from the folder the pane started in, not from the session's worktree. *(the user, 2026-10-24)*
  - Paths in a code span count, and so does the text of a Markdown link. Paths in a code block and in a URL do not.
  - A file edit is not checked: a path in a file keeps the form its file uses.
  - A short path blocks the stop once, the one exception to R1. The message lists each short path, and Claude writes the reply again with full paths. the user sees the message.
  - Serves: F4
- 🚀 **R13. Charts in docs:** [implement] the writing rules in `.claude/CLAUDE.md` has a rule for docs only, not replies. When a doc compares numbers, shows a change over time, or describes data in a table, CSV or sheet, Claude considers a chart. Claude picks the form from the chart catalog that `chart-suggest` keeps. The rule and the chart notes of `chart-suggest` name the same catalog, so they do not drift. *(the user, 2026-10-25)*
  - Serves: F1
- 🚀 **R20. No names in what ships:** [implement] the script, the rules file, this level with its component `chart-suggest`, and the e2e test hold no term of the deny list of `public-release/R37`. They say "the user", not a name, in their text and in each attribution. The name scan of a release passes on each of them. *(the user, 2026-11-23)*
  - Serves: F5
- 🚀 **R19. Works with nothing private:** [implement] with no `.claude/CLAUDE.md`, no chart catalog page, no STE data file and no mode file, each command of the script (`post`, `stop`, `file`, `report`, `--test`) runs with no error. The two term rules and `steWords` then pass, a docs edit gets no chart note, and the mode is `pro`. *(the user, 2026-11-23)*
  - Serves: F5
- 🚀 **R17. On the release list:** [implement] the script, the rules file, this level and an e2e test are on the release list of `public-release/R42`. Then the public `settings.json` keeps the four writing-check hooks by `public-release/R54`. In a fresh clone of the public `nightly`, the config pane shows the report, and a reply or a markdown edit gets checked. *(the user, 2026-11-23)*
  - Serves: F5
  - Design input: `scripts/chart-catalog.py` of `chart-suggest` does not ship. Only the pages of the level do.
  - Design input: the e2e test sits in `tests/e2e/writing-check/`. Its Covers names the script and the rules file, as `public-release/R56` needs.
