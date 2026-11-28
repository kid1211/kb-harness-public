# Knowledge base architecture: design

## State transitions

The model is [knowledge-base-architecture.qnt](knowledge-base-architecture.qnt). Module `kbWrite` is one write by Claude to one KB file, from the hooks' first look to the end. Module `kbPage` is the check of one file at rest: the area its name gives, and the score each heading takes.

```graph
import-graph: architecture.md
```

1. [Start](#start): Claude is about to write a file in a KB. Nothing is written yet.
2. [Dating](#dating): the name has `.source.`. The hook checks the event date, and that the file is new.
3. [Free](#free): the name has `.staging.`. Claude writes with no approval.
4. [Comparing](#comparing): a staging file is written, and Claude compares it with the topic's consolidated page.
5. [Asking](#asking): the name is a plain `.md`, so the file is a consolidated page. The hook checks the page as it will be, then the user must approve.
6. [Written](#written): the write happened, and the check passes the file.
7. [Raised](#raised): a conflict is in a `TODO(P1)` marker, and the user knows. The consolidated page did not change.
8. [Refused](#refused): the write did not happen, and the hook says why.
9. [Flagged](#flagged): Claude wrote a KB file through Bash, past the PreToolUse hook. The PostToolUse hook names it, and Claude tells the user.

## The layout

These rules go into `.claude/CLAUDE.md`, in place of its "Source vs. `kb-*` pages" part. `kb-check.py` tests each one.

- **Topic folder.** Any folder under a domain, such as `member/colon-issue/`. Its files sit side by side, with no folder per area. A sub-folder whose name starts with an ISO date is an event folder: a visit, a trip, a statement. It gives its date to the files in it.
- **Area by suffix.**

  | Name | Area |
  |---|---|
  | `name.source.<ext>`, also `IMG_3724.source.jpeg` | source |
  | `name.staging.<ext>`, also `trend.staging.png` | staging |
  | `name.md` | consolidated |
  | `CLAUDE.md`, any path in a dot folder or in `plans/` | exempt |
  | any other name | none: the check flags it |

- **Event date.** A source name, or its event folder's name, starts with `YYYY-MM-DD`, `YYYY-MM` or `YYYY`. If no part is known, the name starts with `undated-`, and the file says the day it came in. `kb-check.py todo` lists each `undated-` file as a P3 item.
- **Score.** A consolidated page has its root score in the frontmatter, or on the line under the title if it has none:

  ```markdown
  ---
  confidence: 3
  confirmed: 2026-10-23
  ---
  # Member: current status

  ## Medications
  Confidence: 2, 2026-10-23
  ```

  3 is checked against source, 2 sure, 1 likely. A heading with no `Confidence:` line takes its parent's score. The plain line shows in VS Code's preview with no change to the extension, and `grep` finds it.
- **Changed fact.** Under the heading, a line `Changed 2026-11-02: <old value> to <new value>, from <source link>`. Git holds the rest.
- **Missing information.** A line `TODO(P1): <what is missing>` under the heading it belongs to. P1 is high, P2 is middle, P3 is low. The user can write one on each page. Claude writes one on a staging page only: an `undated-` source, a fact with no source, a question research could not settle, a conflict. Claude proposes the priority, and the user's priority wins.
- **Sources.** Each fact on a staging or consolidated page carries `[n]`, and a Sources list links each `n` to a `.source.` file by a relative path. A link to another page is not a source. A staging page can cite a URL with its retrieval date, so research from the web passes. A consolidated page cannot.

## State deep dive

### Start

The PreToolUse hook `kb-guard.sh` gets the path of a Write, Edit or MultiEdit. It reads the area from the name (`classify`). A write through Bash does not reach it (`bashWrite`, see [Flagged](#flagged)).

- `settings.json` has one entry per tool with the matcher `Write`, `Edit`, `MultiEdit` or `Bash`, and no `if`. A KB file can be any type, so no path pattern narrows it.
- The script is shell. It exits 0 first if the path is outside a KB: a folder whose `.claude/CLAUDE.md` is a symlink into the harness. It starts Python only for a KB file.

- **Invariants:** none yet.
- **Expected output:** none on disk.

### Dating

A source file. The hook passes it if the name or its event folder has a date or `undated-`, and the file does not exist yet. An existing source file is source as it came in: the hook returns `ask`, so the user approves a fix, such as a better OCR line (`sourceWith`).

- **Invariants:** `sourceHasDate`, `sourceKeptAsItCame`.
- **Expected output:** a new `.source.` file with a date, or a refusal that names the missing date. PII data or a large file, such as a photo or PDF, goes on the gitignore list and into cloud storage, iCloud or Google Drive, through `media-icloud-sync`, with the suffix on both the symlink and its target.

### Free

A staging file. The hook allows the write (`writeStaging`). `p-research` writes its research here, as `<topic>.staging.md` in the topic folder it serves.

- **Invariants:** `stagingFree`.
- **Expected output:** the staging file, with `[n]` sources and any `TODO` markers Claude adds.

### Comparing

- After a staging write, the PostToolUse hook adds context for Claude: the consolidated pages of the same topic folder, with each `Confidence:` heading.
- Claude reads them and judges if the new text disagrees with a confirmed fact (`compareWith`).
- The judgement is Claude's. No script sees a conflict.

- **Invariants:** `conflictReachesJoe`.
- **Expected output:** none on disk if there is no conflict.

### Asking

The file is a consolidated page (`askJoeWith`).

1. The hook builds the page as it will be, in a temp file. For Write, that is `content`. For Edit, it applies `old_string` to `new_string` on a copy of the page, once or with `replace_all`. For MultiEdit, it applies each edit in turn.
2. It runs `kb-check.py file` on the temp file. If the root score or a source is missing, it returns `deny` with each problem. The user is not asked.
3. Else it returns `permissionDecision: "ask"`, with the reason "consolidated page: the user confirms each change". The Claude Code docs say this prompts the user in auto mode too.
4. The user says yes or no in the prompt.

- **Invariants:** `consolidatedOnlyWithYes`, `consolidatedComplete`, `askOnlyComplete`.
- **Expected output:** the page changes only after the user's yes, and only as a page that passes `kb-check.py file`.

### Written

The write happened. The PostToolUse hook runs `kb-check.py file <path>`: area, date, score and sources. A failure goes back to Claude as context.

- **Invariants:** `safety`.
- **Expected output:** a file that `kb-check.py file` passes. `kb-commit-nudge.sh` commits it later.

### Raised

- Claude found a conflict. It writes `TODO(P1): conflict with <page>#<heading>: <the two values and their sources>` into the staging file.
- It tells the user in the reply, and proposes `/op-fork-new-wt` to settle it in a fork session.
- It does not touch the consolidated page.

- **Invariants:** `conflictReachesJoe`.
- **Expected output:** the marker in staging. `kb-check.py todo` lists it first.

### Refused

The hook denied the write, or the user said no. For a missing date, the hook returns `deny` with the reason, so Claude renames the file and tries again.

- **Invariants:** `consolidatedOnlyWithYes`, `sourceKeptAsItCame`.
- **Expected output:** no change on disk.

### Flagged

Claude wrote a KB file through Bash: `sed`, `mv`, a Python script. The PreToolUse hook did not see it (`bashWrite`).

- Before each Bash call, `kb-guard.sh` stamps a marker file for the session. After it, `kb-after.sh` looks for KB files newer than the marker, ignored photos too. It runs `kb-check.py` on each one it finds.
- Neither Bash entry has an `if`: a Bash command has no path to filter on.
- It returns `additionalContext` that names each changed consolidated page and each problem. The `kb` skill tells Claude to tell the user, who checks the change.
- `/kb check` lists each consolidated page with an uncommitted change too, so a change missed here still shows.

- **Invariants:** `bashFlagged`, `noSilentChange`.
- **Expected output:** the file as Bash left it, and a line to the user that names it.

## Build checks

The build is a skill, `kb`, with a script and hooks.

- **State check:** none. A write has no run state on disk. The hook decides from the path alone.
- **Output check:** `.claude/skills/kb/scripts/kb-check.py`, the one holder of the KB file rules. Each rule prints one line per problem, `<path>: <problem>`, and exits 1 if it found one:
  - `area <kb>`: each file has an area (`checkPasses`, `everyFileHasArea`).
  - `date <kb>`: each source file has a date or `undated-` (`sourceHasDate`).
  - `score <kb>`: each consolidated page has a root score, and each heading's score is its own or its parent's (`rootCoversAll`, `effective`).
  - `sources <kb>`: each `[n]` resolves to a `.source.` file that exists (`citesSource`).
  - `file <path>`: the four rules on one file. The hooks and `p-research` call this one.
  - `all <kb>`: the four rules over a whole KB, then each consolidated page with an uncommitted change (`bashFlagged`). `/kb check` calls it.
- **Listing:** `todo <kb>` prints every `TODO(Pn)` line, P1 first, with its file and heading, and each `undated-` source as P3. A mark is work to do, not a problem, so it exits 0.
- **`/kb recheck <topic>`:** a step of the `kb` skill, not a script. A fresh agent gets the topic's consolidated pages, its staging pages, and each source newer than the page's `confirmed` date. It writes a `TODO(P1)` per conflict into the staging page, as [Raised](#raised) does.
- **Hook tests:** a shell suite runs `kb-guard.sh` and `kb-after.sh` on fake hook input: a new source with and without a date, an old source, a staging file, a complete and an incomplete consolidated page by Write, Edit and MultiEdit, a Bash write, `CLAUDE.md`, and a path outside a KB. One test per invariant of `kbWrite`.
- **Unit tests:** `kb-check.py --test` has one bad tree per rule and one good tree that passes all.
- **Model tests:** `conflictTest`, `noYesTest`, `noScoreTest`, `yesTest`, `bashTest`, `noDateTest`, `oldSourceTest`, `exemptTest`, `safetyTest`, `ownScoreWinsTest`, `noRootScoreTest`, `photoTest`, `rootCoversAllTest`.
- **Invariants:** `sourceHasDate`, `sourceKeptAsItCame`, `stagingFree`, `conflictReachesJoe`, `consolidatedOnlyWithYes`, `consolidatedComplete`, `askOnlyComplete`, `bashFlagged`, `noSilentChange`, `safety`, `rootCoversAll`. `neverWrites` and `everyFileHasArea` are the negative controls.
- **Moves of `kbWrite`:** `start`, `source`, `compare`, `askJoe` and `done` pick the inputs of a move at random. The model tests call the fixed forms.
- **Not checked by a script:** whether Claude sees a conflict, whether the recheck agent finds one, whether a score is right, and whether a page says what is true now. The user reads them.

## Coverage

| Requirement | Held by |
|---|---|
| R1 | not in the model: research, done in the research page on the `Builds:` line |
| R9 | `classify`, `areaOf`, `photoTest`, `exemptTest` |
| R21 | `sourceWith`, `sourceHasDate`, `sourceKeptAsItCame`, `noDateTest`, `oldSourceTest`, `kb-check.py date`, `kb-check.py todo` |
| R4 | `citesSource`, `consolidatedComplete`, `askOnlyComplete`, `kb-check.py sources`. For staging, only the script checks it |
| R12 | `writeStaging`, `stagingFree` |
| R22 | `askJoeWith`, `consolidatedOnlyWithYes`, `askOnlyComplete`, `effective`, `rootCoversAll`, `noYesTest`, `noScoreTest`, `ownScoreWinsTest`, `kb-check.py score` |
| R7 | `compareWith`, `conflictReachesJoe`, `noSilentChange`, `conflictTest`. Whether Claude sees the conflict is not modelled |
| R8 | not in the model: what the `kb` skill tells Claude to read first is prose. The `p-research` change is in its own plan |
| R23 | `compareWith` sets the var todoP1. `kb-check.py todo` lists it. Who writes a mark where is a rule of the `kb` skill, not modelled |
| R24 | `checkPasses`, `everyFileHasArea`, `kb-check.py file`, called by the hooks and `p-research` |
| R27 | not in the model: a list of folders in the hooks, with no state. `kb-check.py` tests the list |
| R28 | not in the model: the `kb` skill and the other skills name the layout in prose. A skill test checks the headings |
| R29 | not in the model: where a run folder sits is a name rule of `kb-check.py file`. `p-research` writes there |
| R30 | not in the model: the component `kb-object-model` holds the types, with its own model and checks. The Write step of the `kb` skill writes them |
| raised | `conflictTest` |
| refused | `noYesTest` |
| flagged | `bashTest` |
| written | `exemptTest` |
| R25 | `bashWrite`, `bashFlagged`, `bashTest`, `kb-check.py all`. The topic recheck is an agent step, not modelled |

## Proposed components

Not created. The user decides which to make.

- **`kb-check`**: the script and its tests. Own built files.
- **`hooks`**: `kb-guard.sh` (PreToolUse) and `kb-after.sh` (PostToolUse), and their lines in `.claude/settings.json`.
- **`skill-updates`**: the other skills that write KB files and must use the suffixes: `ocr-translate-medical-record`, `mortgage-rates`, `trade-price-recon`, `submit-insurance-claim`, the `finance-connector-*` skills, `media-icloud-sync`.

## Risks

- **The hook sees Write and Edit only.** A `sed`, `mv` or Python write through Bash passes it. The model holds this as [Flagged](#flagged): the PostToolUse hook names the change after the fact, and `/kb check` lists it again. The `kb` skill tells Claude to write KB files with Write and Edit only.
- **The Bash hook runs on every Bash call.** A Bash command has no path for `if` to match. `kb-after.sh` is shell, and exits at once outside a KB, so the cost is one shell start per Bash call.
- **`ask` in `bypassPermissions` and `acceptEdits` is not in the docs.** The docs say `ask` prompts in auto mode. Test the other two modes in the build. If `ask` does not prompt there, the hook returns `deny` with the reason, and Claude asks the user in the reply.
- **Today's files have no suffix.** No move brings them in (R27). The hooks act only on the folders in a list, and the user adds a folder when it follows the layout. No page counts as confirmed before the user confirms it.
- **Other skills write KB files.** Until each one uses the suffixes, the hook flags its files. The `skill-updates` component lists them.
- **A missed conflict.** Claude judges a conflict, and a practitioner report says Claude "doesn't spontaneously notice" such conflicts (research page, Q2). The PostToolUse context puts the confirmed headings in front of Claude on each staging write. Nothing checks that it read them.
- **Scores rot.** No source shows that a human score stays current (research page, Q5). The `confirmed` date shows the age. A later `kb-check.py` rule can flag a score older than a year.
- **The `.adoc` pages.** 206 transcripts are `.adoc`. The move makes them `.source.adoc`. The hook of `trigger-kb-adoc` goes with that skill, so nothing checks their AsciiDoc after the move.
- **R8 is two things.** The `kb` skill is built here. The `p-research` change is in its own plan, and this plan only uses it.

## Appendix

- Research: `knowledge-base-architecture-research-2026-10-23.md` in the `claude-research` domain of the `personal` KB, and its three dumps in `raw-deep-research/`.
- Claude Code hooks, retrieved 2026-10-23: https://code.claude.com/docs/en/hooks for `permissionDecision` and `additionalContext`, https://code.claude.com/docs/en/permission-modes for `ask` in auto mode.
- Today's KB, counted 2026-10-23 with `find` over `personal` for `.md`/`.adoc` pages, media names and symlinks, and with `grep -rlE '\]\((\.|[a-z0-9])[^)]*\)|link:[^h]' --include='*.md' --include='*.adoc'` for pages with relative links.
- Kept markers: `.claude/lib/palette/kitchen-sink.md` keeps no emoji, so the score and the `TODO` marker are plain text.
- To check the model again, from the harness root:

  ```sh
  npx quint typecheck plans/knowledge-base-architecture/knowledge-base-architecture.qnt
  npx quint test plans/knowledge-base-architecture/knowledge-base-architecture.qnt --main=kbWrite
  npx quint test plans/knowledge-base-architecture/knowledge-base-architecture.qnt --main=kbPage
  npx quint run plans/knowledge-base-architecture/knowledge-base-architecture.qnt --main=kbWrite --invariant=neverWrites --max-steps=5
  npx quint run plans/knowledge-base-architecture/knowledge-base-architecture.qnt --main=kbPage --invariant=everyFileHasArea --max-steps=0
  ```
