# Session retro: detailed requirements

## Requirements

Terms used below, and in the components:

- The session is the Claude Code session that ran `worktree-end`, by its session ID. Its transcript is the `.jsonl` file of that session.
- The retro is the run that reads the transcript and writes the findings.
- A finding is one event in the transcript, its cause, a proposed change to the harness, and a tip for the user where one applies.

The component `findings` covers what the retro looks for. The component `findings-page` covers the page it writes and how the user settles each finding.

- ✅ **R1. Start when the user says yes:** [implement] After each ExitWorktree call of `worktree-end`, with keep or remove, `worktree-end` asks the user "Run a session retro?", yes or no. A yes starts the retro. A no starts nothing. Nothing else starts it: a KB session on `main` gets no retro.
  - If `worktree-end` calls ExitWorktree again, it asks again.
  - If the retro fails, it writes why into a failure log. The reminder of R10 shows the log at the start of the user's next session.
  - Serves: F1
- ✅ **R15. No turn in the session:** [implement] Apart from the question of R1, the retro adds no turn, no question and no wait to the session. The session's transcript file does not change, and the retro leaves no transcript of its own. The retro does not edit the harness, a consolidated KB page or the worktree.
  - Serves: F1
- ✅ **R16. Commit only its own page:** [implement] When the retro has written its page, a script commits that page alone in `personal`, by its path, on `main`, and pushes it. It runs `git pull --rebase` before the push. The model of the retro runs no git command.
  - Serves: F3
- ✅ **R7. Reuse what exists:** [research] What do Anthropic and Hermes Agent already do to learn from a finished session? Use an Anthropic feature where it covers a requirement, instead of a new build. Hermes is not installed. Copy a small script or library from it only if it is worth it.
  - Serves: F4
- ✅ **R10. A weekly reminder:** [implement] At session start, if 7 days or more have passed since the last reminder, a hook brings the user the count of open findings over all pages. The user picks which ones to fix.
  - A pattern is one kind with one subject, such as one hook, in 2 sessions or more. The reminder names each pattern.
  - Serves: F3
- ✅ **R11. Find blocks, loops and corrections:** [implement] The retro finds hook blocks, loops of duplicate work, and corrections by the user. The component `findings` holds the rules for each.
  - Serves: F2
- ✅ **R17. A findings page per session:** [implement] The component `findings-page` gives the page the retro writes, and the way the user settles each finding on it.
  - Serves: F3
- ✅ **R14. Use the session's own model, at once:** [implement] The retro runs on the session's own model, right after ExitWorktree, so it reads the session's prompt cache. If the last entry of the transcript is more than an hour old, the retro does not read the transcript. It writes a one-line page that says why.
  - Serves: F2
