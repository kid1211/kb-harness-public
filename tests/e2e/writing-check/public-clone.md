# writing-check: a fresh clone checks a markdown edit, and the config pane shows the report

## Covers

- `.claude/hooks/writing-check.py`
- `.claude/hooks/writing-rules.md`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make an empty folder `$T/home`. Each step below runs with `HOME=$T/home`, so no mode file, STE data or chart catalog is there.

## Steps

1. In `$T/h`, run `python3 -I .claude/hooks/writing-check.py --test`.
2. In `$T/h`, run `python3 -I .claude/hooks/writing-check.py report`.
3. In `$T/h`, run `claude -p "Write the file notes.md with one line: We utilize the vault to leverage it." --allowedTools Write`.
4. In `$T/h`, start `claude`, and press the `⚙ config` button above the prompt.

## Expected

1. Step 1 prints `ok`.
2. Step 2 exits 0, prints a table with the rule `bannedWords`, and prints nothing on stderr.
3. In step 3, the hook sends feedback that names `.claude/hooks/writing-rules.md` and the rule `bannedWords`, and Claude writes the line again.
4. In step 4, the Writing check pane opens and shows the same table as step 2, with no error.

## Cleanup

1. Delete `$T`.
