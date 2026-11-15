---
name: session-retro
description: When the user says yes at the end of `worktree-end`, find the blocks, loops and corrections of the session. Write them to a staging page in the `personal` KB.
when_to_use: Use on `/session-retro`, or when the user asks what the retros found.
user-invocable: true
---

# Session retro

Plan: `plans/session-retro/`.

`S` stands for `.claude/skills/session-retro/scripts`, run from the harness root.

## How it runs

- `worktree-end` asks the user after each ExitWorktree. On a yes it runs `S/start.sh`, which starts `S/retro.sh` in the background.
- `S/retro.sh` reads the transcript. If it is fresh, a fork of the session judges the candidates of `S/findings.py`. Else it writes a one-line page. `S/findings-page.py` writes the page, and `S/commit-page.sh` commits it alone in the KB.
- `S/reminder.sh` is the `SessionStart` hook, on a new session. It shows the failure log, and once in 7 days the open findings.
- State, logs and failures are in `~/.claude/session-retro/`.

## /session-retro

1. Run `python3 -I S/findings-page.py summary`. This is the state check: the count of open findings and each pattern.
2. Run `python3 -I S/findings-page.py confirmed`. List the confirmed findings, which the user can move into a harness change.
3. Show both lists, and the path of the pages: `claude-research/session-retro/` in `personal`.
4. If `~/.claude/session-retro/failures.log` has lines, show them.
5. For each page, run the output check: `python3 -I S/findings-page.py check <page>`, then `python3 -I .claude/skills/kb/scripts/kb-check.py file <page>`. Report each line it prints.
6. Tell the user: to settle a finding, change its `Status:` line to `confirmed` or `dropped`. Do not change a status yourself.
