# session-retro: an old transcript gets a one-line page, committed alone

## Covers

- `.claude/skills/session-retro/`

## Setup

1. Make a temp folder `$T`.
2. Make a throwaway KB `$T/kb`: a git repo with one commit, a bare origin `$T/kb-origin.git`, and the folder `claude-research/session-retro/`. Write `$T/kb/other.md` with no commit.
3. Make `$T/projects/p/<sid>.jsonl`, with `<sid>` a made-up session ID. Each line has a `timestamp` more than 60 minutes old.
4. Put a stub `claude` in `$T/bin/claude` that logs each call to `$T/claude.log` and exits 0.
5. Set `CLAUDE_CODE_SESSION_ID=<sid>`, `SESSION_RETRO_PROJECTS=$T/projects`, `SESSION_RETRO_KB=$T/kb`, `SESSION_RETRO_STATE=$T/state`, `SESSION_RETRO_CLAUDE=$T/bin/claude` and `SESSION_RETRO_SETTLE=0`.

## Steps

1. Run `bash .claude/skills/session-retro/scripts/start.sh` from the harness checkout under test.
2. Wait until `$T/state/lock-<sid>` is gone, 60 seconds at most.
3. Ask Claude: "/session-retro", with the same environment.

## Expected

1. Step 1 prints `STARTED` and returns at once.
2. `$T/claude.log` is empty: an old transcript starts no fork.
3. One new page is in `$T/kb/claude-research/session-retro/`, with one line about the old transcript.
4. `git -C $T/kb log -1 --name-only` names only that page. `other.md` is still uncommitted.
5. `$T/state/failures.log` does not exist, or is empty.
6. `python3 -I .claude/skills/session-retro/scripts/findings-page.py check <page>` prints no fail.
7. The reply of step 3 shows the count of open findings, the confirmed list and the path of the pages. It changes no `Status:` line.

## Cleanup

1. Delete `$T`.
