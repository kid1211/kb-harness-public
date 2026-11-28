# session-retro: the release copy, with no spec skill, still writes and commits each page

## Covers

- `.claude/skills/session-retro/`
- `scripts/public-release/paths.txt`

## Setup

1. Make a temp folder `$T`.
2. Make the release copy `$T/pub`: for each line of `scripts/public-release/paths.txt` of the harness checkout you test that is not empty and not a comment, run `rsync -aR <line>` from that checkout into `$T/pub/`. Then copy `scripts/public-release/public/` into `$T/pub/`.
3. Make a throwaway KB `$T/kb` as in setup step 2 of `tests/e2e/session-retro/old-transcript-page.md`, with `$T/kb/.claude/CLAUDE.md` a symlink to `.claude/CLAUDE.md` of the harness checkout you test.
4. Write two transcripts, each line with a `timestamp` more than 60 minutes old, so no fork starts:
   - `$T/plain.jsonl`: a user prompt and an assistant reply, and no commit.
   - `$T/spec.jsonl`: the same, then an assistant `Bash` tool call `git commit -m "[automatic after p-req] plans/demo: wants"` and its `tool_result` with the text `ok`.
5. Set `SESSION_RETRO_KB=$T/kb`, `SESSION_RETRO_STATE=$T/state`, `SESSION_RETRO_CLAUDE=false` and `SESSION_RETRO_SETTLE=0`.

## Steps

1. In `$T/pub`, run `bash tests/skills/session-retro/test-session-retro.sh`, `python3 -I tests/skills/session-retro/test-spec-rounds.py`, `python3 -I tests/skills/session-retro/test-findings-page.py` and `python3 -I tests/skills/session-retro/test-findings.py`.
2. Run `bash scripts/public-release/scan.sh names $T/pub` from the harness checkout.
3. Run `bash $T/pub/.claude/skills/session-retro/scripts/retro.sh aaaaaaaa-plain $T/plain.jsonl $T`.
4. Run `bash $T/pub/.claude/skills/session-retro/scripts/retro.sh bbbbbbbb-spec $T/spec.jsonl $T`.
5. Delete `$T/pub/.claude/skills/session-retro/scripts/spec-rounds.py`, then run step 4 again with the session ID `cccccccc-nospec`.

## Expected

1. `$T/pub` holds no `.claude/skills/spec/` and no `.claude/skills/p-build/`.
2. Each suite of step 1 ends with `0 failed` or `all pass`.
3. Step 2 prints no line and exits 0.
4. After step 3, `$T/state/runs.log` has `spec rounds: skipped for now: no spec round`. The page `*-aaaaaaaa.staging.md` has no `## Spec` line. `git -C $T/kb log -1 --name-only` names only that page, and `spec-rounds.csv` does not exist.
5. After step 4, the page `*-bbbbbbbb.staging.md` has a `## Spec` section, and `git -C $T/kb log -1 --name-only` names that page and `claude-research/session-retro/spec-rounds.csv`.
6. After step 5, `$T/state/runs.log` has `spec rounds: skipped for now`, the page `*-cccccccc.staging.md` is committed alone with no `## Spec` line, and `spec-rounds.csv` has no row of `cccccccc`.
7. `$T/state/failures.log` does not exist, or is empty.

## Cleanup

1. Delete `$T`.
