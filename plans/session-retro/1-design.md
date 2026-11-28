# Session retro: design

## State transitions

Model: [session-retro.qnt](session-retro.qnt), module `sessionRetro`. The page states are in the model of the component findings-page.

```graph
import-graph: architecture.md
```

1. **Idle:** no run. A session on `main` stays here.
2. **Running:** `retro.sh` runs in the background after the user says yes (`ask`, `askWith`).
3. **Cold:** the last transcript entry is over an hour old (`decide`).
4. **Forked:** a fork of the session judges the candidates (`decide`, `read`).
5. **Written:** the page is in `personal` (`writePage`).
6. **Committed:** the page is committed, and pushed or logged (`commit`).
7. **Failed:** a step failed, and the failure log has why (`runFails`).

The reminder runs at each new session start (`sessionStart`). Days pass between sessions (`dayPasses`).

The KB path comes from `SESSION_RETRO_KB`, which is `~/second-brain/personal` when it is not set. State lives in `~/.claude/session-retro/`.

## State deep dive

### Idle

After each ExitWorktree call, Step 5 of `worktree-end` asks "Run a session retro?" with AskUserQuestion, yes or no. A no starts nothing. On a yes, it runs `scripts/start.sh` from the main checkout, where ExitWorktree left the session:

- It takes the session ID from `CLAUDE_CODE_SESSION_ID`, which Claude Code sets for each Bash call. If it is not set, it prints `NO_SESSION`.
- It finds the transcript at `~/.claude/projects/*/<session ID>.jsonl`. If there is none, it prints `NO_TRANSCRIPT`.
- It starts `nohup retro.sh <session ID> <transcript> <current folder> </dev/null >/dev/null 2>&1 &`, prints `STARTED`, and returns at once. A job started this way outlives the Bash call: tested on 2026-10-24.

A KB session on `main` never runs `worktree-end`, so no run starts.

- **Invariants:** `noRunWithoutYes`.
- **Expected output:** one line from `start.sh` in the session.

### Running

`retro.sh` takes the lock of the session, a folder made with `mkdir` that holds its PID:

- If the lock is held, the run waits up to 10 minutes, then fails and logs it. A lock whose PID is gone, or with no PID after a minute, is stale, and the run takes it.
- It waits until the transcript has not grown for 3 seconds, for 60 seconds at most. The transcript is written in the background, so its last lines can lag.
- It reads the timestamp of the last transcript entry.

It never writes to the transcript, the harness or the worktree. The page is its only output in a repo.

- **Invariants:** none.
- **Expected output:** a line in `~/.claude/session-retro/runs.log`.

### Cold

The last entry is more than 60 minutes old (`decide`). The run does not run the scan or the fork. `findings-page.py cold` writes the one-line page.

- **Invariants:** `coldNoRead`.
- **Expected output:** the one-line page of findings-page.

### Forked

The age is 60 minutes or less. The hour is a fallback: the run starts within seconds of ExitWorktree, while the cache is warm.

1. `findings.py scan` lists the candidates.
2. The run changes to `restoredCwd`, so `--resume` finds the session, even after the worktree is gone.
3. It starts `claude --resume <id> --fork-session -p <prompt> --model <session model> --max-turns 1 --no-session-persistence --permission-mode dontAsk --settings '{"disableAllHooks":true}' --output-format json`.
4. The session model is the `message.model` of the last assistant line that is not `<synthetic>`. If that line's context tokens (input, cache read and cache write) are over 200,000, the run adds `[1m]`.
5. The prompt is `references/findings-prompt.md` with the kinds and the candidates. It says: use no tool, return JSON only.
6. `findings.py check` reads the `result` field (`read`).

`disableAllHooks` keeps the session's hooks, such as the reminder, out of the fork. `--no-session-persistence` leaves no transcript. A fork that fails, or returns no JSON, is a failure. The run logs `cache_read_input_tokens` and the cost from the JSON. A read with no cache is a log line, so a cost of about $3 shows.

- **Invariants:** `readOnlyWhenFresh`.
- **Expected output:** the findings JSON of the component findings.

### Written

`findings-page.py full`, or `cold`, writes the page in the pending folder. `findings-page.py move` checks it for secrets and moves it into `claude-research/session-retro/` of `personal` (`writePage`).

- **Invariants:** none.
- **Expected output:** `claude-research/session-retro/<date>-<first 8 of the session ID>.staging.md` in `personal`.

### Committed

`scripts/commit-page.sh <page>` (`commit`):

1. Refuse if the branch of `personal` is not `main`.
2. Run the secret check and `kb-check.py` on the page.
3. Take the lock of `kb-commit-nudge.sh` for the repo: `<its state folder>/lock-<cksum of the repo path>`, waiting up to 60 seconds.
4. `git add -- <page>`, then `git commit -- <page>`. Only the page is staged.
5. `git pull --rebase --autostash`, then `git push`. A failed pull or push leaves the commit, and logs it.

The model of the fork runs no git.

- **Invariants:** `failuresKept`.
- **Expected output:** one commit on `main` of `personal`, pushed.

### Failed

`retro.sh` appends the date, the session ID and the reason to `~/.claude/session-retro/failures.log` (`runFails`). A run again starts on the next yes.

The `SessionStart` hook with matcher `startup` runs `scripts/reminder.sh` (`sessionStart`). It does not run on resume, clear or compact:

- If the failure log has a line, it shows each line and empties the log.
- If `last-reminder` is missing, or 7 days or more old, it shows the count of open findings over all pages, and each pattern. A pattern is one kind and subject in 2 sessions or more. `findings-page.py summary` gives both. Then it writes the date into `last-reminder`.
- It sends the text as `systemMessage`, which the user sees, and as `additionalContext`, which tells Claude.

The `/session-retro` command of `SKILL.md` shows the same summary on request, with the confirmed findings. It starts no run.

- **Invariants:** `failuresKept`.
- **Expected output:** the reminder text, or nothing.

## Build checks

Bash tests in `tests/skills/session-retro/test-session-retro.sh`, with a stub `claude`, a throwaway `personal` git repo with a bare `origin`, and a written transcript. Python unit tests in `tests/skills/session-retro/test-findings.py` and `test-findings-page.py`. The model runs `coldRunTest`, `fullRunTest`, `noStartsNothingTest`, `failShownTest`, `weeklyTest`, `notBeforeSevenTest`, `againAfterCommitTest`, `noReadWhenOldTest`, `firstReminderTest` and `noStartWhileRunningTest` give the cases. `committedTest` reaches the end state. `startRun` is the move that starts them.

| Test | Holds |
|---|---|
| `start.sh` prints `STARTED` and returns in under a second while a stub `retro.sh` sleeps 5 seconds | `ask` |
| `start.sh` with a real `retro.sh` writes the page | `ask` |
| `start.sh` with no session ID, or no transcript, prints why and starts no run | `noRunWithoutYes` |
| an old transcript gives a cold page, and the stub `claude` is not called | `decide`, `coldNoRead` |
| a fresh transcript calls the stub `claude` with `--fork-session`, `--no-session-persistence`, `disableAllHooks` and the session model | `read`, `readOnlyWhenFresh` |
| a `<synthetic>` last line is skipped for the model | `read` |
| the transcript is byte for byte the same after a run | R15 |
| the run commits one file, the page, and pushes it to the bare origin | `commit` |
| a dirty tracked file in `personal` stays uncommitted, and the push still works with the origin ahead | `commit` |
| `personal` on a branch other than `main` is refused | `commit` |
| a stub `claude` that fails writes a line to the failure log | `runFails`, `failuresKept` |
| a page with a secret is not in `personal`, and the log says why | `runFails` |
| a second run on the same session waits for the lock, then runs | `ask` |
| the reminder shows the failure log as `systemMessage`, then empties it | `sessionStart` |
| the reminder shows the count at 7 days and with no `last-reminder`, not at 6 | `sessionStart`, `dayPasses` |
| the reminder names a pattern in 2 sessions | `sessionStart` |

The negative control `neverFails` must fail in the model run.

No check can see:

- the cost of a real fork, or that the cache was warm. The research measured $0.10 warm and $3.10 cold, on a session that had ended.
- that the user gets the question in a live `worktree-end`. No test runs the skill.

## Coverage

| Requirement | Held by |
|---|---|
| committed | `committedTest` |
| failed | `failShownTest` |
| R1 | `ask`, `noRunWithoutYes`, `noStartsNothingTest`, `runFails`, `failuresKept`. Not in the model: the question itself, in `worktree-end` |
| R15 | the Bash tests: `start.sh` prints one line and returns at once, and the transcript does not change. Not in the model: no action could change the session |
| R16 | `commit`, and the Bash tests of the commit. Not in the model: that only the page is staged |
| R7 | research only: Anthropic's `/insights` is the example the components copy. Nothing ships that replaces this skill, and Hermes gives no code to lift |
| R10 | `sessionStart`, `dayPasses`, `weeklyTest`, `notBeforeSevenTest` |
| R11 | `writePage`, the component findings |
| R17 | the component findings-page |
| R14 | `decide`, `read`, `readOnlyWhenFresh`, `coldNoRead` |

## Risks

- **Claude Code changes the transcript.** `start.sh` and the scan read a few fields. The tests name each field, so a change shows as a failed test.
- **`start.sh` is not in the main checkout.** `worktree-end` finds it by the top of the main checkout, so it is there only after the merge. Before that, Step 5 says the retro is not merged yet.
- **Claude Code drops `CLAUDE_CODE_SESSION_ID`.** `start.sh` then prints `NO_SESSION`, and Step 5 shows the line.
- **The fork asks for a tool.** `--permission-mode dontAsk` denies it, and `--max-turns 1` stops the run. A fork with no JSON is a failure, shown at the next start.
- **`disableAllHooks` changes the prompt.** The cache could then miss. The run logs the cache read, so the first runs show it.
- **The fork starts while the session is still open.** The research forked a session that had ended. A fork of an open session was not tested.
- **A push fails, such as with no network.** The page stays committed. The failure log says so, and the next `kb-commit-nudge` flush or retro run pushes it.
- **A rebase conflict.** The commit stays, the log says so, and the user pushes by hand.

## Appendix

- `trigger-and-run.staging.md` in `personal`, `claude-research/staging/2026-10-24-session-retro/`: the hook test, the fork command, and the cost runs.
- `anthropic-features.staging.md`: the feature table behind R7.
- `hermes-learning-loop.staging.md`: the review ideas behind R10.
- `.claude/hooks/kb-commit-nudge.sh`: the lock and the hook-free `claude -p` this design reuses.
- Model checks, from the harness root:

  ```sh
  npx quint test plans/session-retro/session-retro.qnt --main=sessionRetro
  npx quint run plans/session-retro/session-retro.qnt --main=sessionRetro --invariant=neverFails   # must report a violation
  ```
