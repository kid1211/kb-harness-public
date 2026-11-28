# Session retro: designs not chosen

- **An `op-fork` that the user starts.** Not chosen: R1 says the run starts on its own, and R15 says it adds no turn.
- **The `PostToolUse` hook on ExitWorktree.** Used until 2026-10-24. Not chosen since: R1 now asks the user first, and a hook cannot ask. `worktree-end` asks and runs `start.sh`. This also drops the wait for a new session to load the hook.
- **A SessionEnd hook.** Not chosen: it fires for every session, KB sessions on `main` too, and has a 1.5 s limit. The ExitWorktree hook fires only in a worktree.
- **The model writes and commits the page.** Not chosen: R16 says the model runs no git. A fork with tools would also break the prompt cache, and the `kb-commit-nudge` hooks would commit its page a second time.
- **A cheaper model, such as Sonnet.** Not chosen: a model other than the session's misses the cache. It cost $3.10 against $0.10 in the research.
- **`claude --bare`.** Not chosen: it needs `ANTHROPIC_API_KEY`, which this machine does not use.
- **Import the `findings-page` model.** Not chosen: its vars would have to move in each action here, and no invariant here reads them. Here a page is one step.
- **`git pull --rebase` with no autostash.** Replaced after the fresh check: another session's dirty file in `personal` makes the pull fail, so most runs would fail. The design adds `--autostash` and the lock of `kb-commit-nudge.sh`.
- **The fork with the session's hooks.** Replaced after the fresh check: the fork is a new session, so `SessionStart` hooks ran in it and used up the weekly reminder. The fork runs with `disableAllHooks`, and the reminder runs only on `startup`.
- **The reminder as `additionalContext` only.** Replaced after the fresh check: only Claude sees it. It also goes out as `systemMessage`, which the user sees.
- **Invariants that no action could break.** Replaced after the fresh check: the hook input and the transcript age are now choices of the model, and the failure log is a count each failure adds to. R15 and the page-only commit are held by the Bash tests.
