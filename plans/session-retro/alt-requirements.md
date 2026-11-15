# Session retro: dropped requirements and closed questions

## R1. Start when worktree-end ends

**Requirement:** The retro starts on its own after each ExitWorktree call that succeeds, with keep or remove. The user does not type a command for it.

**Why it is not chosen:**

- The user wants to choose each time. A retro costs up to $1, and not every session is worth one.
- The new R1 asks the user yes or no at the end of `worktree-end`. Dropped 2026-10-24 by the user.

## R3. Hook blocks

**Requirement:** The retro makes a finding for each block: a hook that denied or asked on a tool call, a hook that sent Claude back after a call or at a stop, Claude Code's own guards, and a call the user rejected. Each finding also says whether the block was right, and whether Claude could have avoided it.

**Why it is not chosen:**

- R3, R4 and R5 cite the same part, the reading of the transcript. They moved into the component `findings`, as its R1 to R3.
- Its R1 adds a hook that failed: research found 100 failures of a missing script in 5 sessions.
- R11 takes their place here. Dropped 2026-10-24.

## R4. Loops and duplicate work

**Requirement:** The retro makes a finding for each place where the session did the same work twice or went in a circle.

**Why it is not chosen:** moved into the component `findings`, as its R2, with a test run after a fix named as not a loop. Dropped 2026-10-24.

## R5. Back-and-forth with the user

**Requirement:** The retro makes a finding for each place where the user corrected how Claude read their words or what Claude did.

**Why it is not chosen:** moved into the component `findings`, as its R3. Dropped 2026-10-24.

## R6. Findings go to staging

**Requirement:** The retro writes one staging page per session in a domain of the `personal` KB, by the `kb` skill. Each finding links to the session ID and its place in the transcript. The page holds no password, token, key or account number from the transcript.

**Why it is not chosen:**

- A fresh check found two ideas in it: where the page goes, and what it must not hold.
- Both moved into the component `findings-page`, as its R1 and R2. R12 takes their place here. Dropped 2026-10-24.

## R8. Learn over time

**Requirement:**

- About once a week, a reminder brings the user the open findings of all sessions. The user sees patterns across sessions and picks which ones to fix.
- A finding is open until the user confirms or drops it. A finding moves out of staging only after the user confirms it.

**Why it is not chosen:** a fresh check found two ideas in it: the reminder, and the life of a finding. The reminder is R10. The life of a finding is R3 of `findings-page`. Dropped 2026-10-24.

## R9. Keep the cost of a run small

**Requirement:** A retro run costs a few cents for a usual session. It never costs more than a limit the user sets. If a run would pass the limit, it stops and its page says so.

**Why it is not chosen:**

- Research found that `--max-budget-usd` is not a hard stop: a cold run cost $3.10 under a $2 limit.
- The cost depends on the prompt cache. The user chose the rule that keeps the cache warm. R14 takes its place. Dropped 2026-10-24.

## R13. Track /insights over time

**Requirement:** About once a month, the reminder of R10 asks the user to run `/insights`. The retro keeps each report, by its date, next to the findings pages. The user can then compare the reports, and see if the harness gets better.

**Why it is not chosen:**

- The user said the retro does not learn from the output of `/insights`. It is an example of how to build the retro.
- Its design ideas went into R4 of `findings`. Dropped 2026-10-24.

## R2. Stay out of the session's way

**Requirement:**

- The retro adds no turn, no question and no wait to the session. The session's transcript gets no entry from it.
- It writes and commits only its own findings page. It does not edit the harness, a consolidated KB page or the worktree.

**Why it is not chosen:**

- A fresh check found two ideas in it: no effect on the session, and what the retro commits.
- No answer said who commits, since the fork may only Read and Write. R15 and R16 take its place. Dropped 2026-10-24.

## R12. One page per session, settled by the user

**Requirement:** The retro writes one staging page per session, with no secrets, and the user settles each finding. The component `findings-page` holds the rules.

**Why it is not chosen:** it repeated three rules of the component. R17 only names what the component gives. Dropped 2026-10-24.

## Closed questions

### Should the retro use the session's own model, and write a one-line page if the cache is cold?

**Answer:** yes. R14 gives it. Closed 2026-10-24 by the user.

### Should the pages go into `claude-research/session-retro/`, not a new domain?

**Answer:** yes. R4 of `findings-page` gives it. Closed 2026-10-24 by the user.

### Will the user run `/insights`, so the plan can compare it with the retro?

**Answer:**

- Yes, once, as an example of how to build the retro, not to track it. The user ran it on 2026-10-24.
- R4 of `findings` takes its ideas. Closed 2026-10-24 by the user.

### Should a later build run the retro for KB sessions on `main`?

**Answer:** no. R1 says a KB session gets no retro. Closed 2026-10-24 by the user.

### Which event marks the end of `worktree-end`?

**Answer:** a `PostToolUse` hook with matcher `ExitWorktree`. It fired for keep and for remove in a test, with the session ID and the transcript path. R1 gives it. Closed 2026-10-24 by Claude.

### Which way to run the retro keeps out of the session?

**Answer:** a design question, done in research: a headless fork in the background, `claude --resume <id> --fork-session -p`, with a script that marks candidates first. The user picks the option at design. Closed 2026-10-24 by Claude.
