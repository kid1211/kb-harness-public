# Op skills

## Goal

Two skills that act on the current Claude session in cmux. 7 requirements, 0 components.

- `op-fork-keep` forks the session into a new pane in the same directory.
- `op-fork-new-wt` forks it into a new pane in a new worktree from `main`.

Builds: `.claude/skills/op-fork-keep/`, `.claude/skills/op-fork-new-wt/`, the check scripts of each (R25), and `tests/skills/op-fork/`. Removes `.claude/skills/op-kb-diff/` and `tests/skills/op-kb-diff/`.
Uses: the `claude` CLI (`--resume`, `--fork-session`), the `cmux` CLI, git

The IDs skip numbers where a requirement changed. The old text is in [alt-requirements.md](alt-requirements.md).

## Architecture

The graph text is in [architecture.md](architecture.md). The user flows of the old layout are in [alt-design-decisions.md](alt-design-decisions.md), for `p-design` to write the graph from.

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** I fork my session in a new pane, in place or in a new worktree.
  Decision: pending
  Built: 0 of 3
  What Claude thinks the user means: I want to branch a session fast and keep working in both.
- **F2.** I open a session's KB changes in VS Code to review them.
  Decision: dropped
  Built: 0 of 1
  What Claude thinks the user means: I want a diff window for what a session changed in a KB.
- **F3.** Each skill finds its own facts, checks itself, and works anywhere.
  Decision: pending
  Built: 0 of 3
  What Claude thinks the user means: I want skills that do not ask me for facts and work in a worktree or the main checkout.
- **F4.** These skills add little to my context.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: I run them often, so I want them small.

## Open questions

- ⚠️ designed check 2026-11-02 (Frieren; the build shows whether each is real):
  - ✅ `commandFailed` sets `worktrees' = 0` but `fork.sh` left a worktree made by `-w`. Real: the new test showed it. `fail()` now removes the worktree and branch, and the design and graph say so. *(Claude, 2026-11-02, recommended)*
  - ✅ [major] `op-kb-diff` with several KB roots: `codeOk` sets one window (`op-skills.qnt:74`). A failure on a later root leaves the first window open, yet `commandFailed` sets `windows' = 0`.
    - Answer: moot. `op-kb-diff` is removed (R22 dropped). Closed 2026-11-15 by the user.
  - minor: state check names differ across R-lines, graph and design ("partial"). minor: no timeout edge for the 10-second wait. minor: `command_failed` text says pane for all skills. minor: no run covers `opening -> commandFailed`. minor: no check for the R22 dark theme. minor: R20 coverage row lacks the third case. minor: branch name `fork-<8>` vs `worktree-fork-<...>` (R23). minor: stray comma `1-design.md:124`. minor: `facts?` before `route?`. minor: 0-index says "Draft" and "Built: 0 of N" for built skills. minor: `alt-design-decisions.md` has no old flows. minor: `req-active.md:25` links a missing anchor.
- ✅ Can a skill read the session facts from `/status`?
  - Answer: No. `/status` is a slash command that only the user can type, so a skill cannot run it. The same facts are there without it (R1): the environment variable `CLAUDE_CODE_SESSION_ID` holds the session ID (seen with `env` in a cmux session, Claude Code 2.1.303), and a directory is a linked worktree when `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`. Closed 2026-10-18 by Claude.
- ✅ If the session is in a worktree, does the fork get a new worktree or run in the same one?
  - Answer: The same one. `op-fork` forks in the session's own directory, worktree or not, as in the user's test (R7). The two sessions share the files, the git index and the branch. Closed 2026-10-18 by the user.
- ✅ Should a fork get its own worktree?
  - Answer: The user chooses each time, with two skills. `op-fork-keep` forks in the same directory (R7). `op-fork-new-wt` forks into a new worktree from `origin/main` (R23). A fork in the same worktree can never own it, so `worktree-end` in that fork cannot remove it. That broke the close of a fork's work on 2026-10-20, after PR #54. [Research Q5](research/fork-session.md#q5-same-worktree-or-new-worktree-for-the-fork-of-a-session-in-a-worktree) had compared the two options and recommended a new worktree from the session's HEAD. The user chose `main` as the start, not the session's HEAD. Closed 2026-10-20 by the user.
- ✅ Who starts the checks of a run?
  - Answer: The skill's script, as its last step. A check prints nothing on a pass (R19). The user's rule says scripts check each run, and their footprint rule (R14) wants no extra steps for Claude. Closed 2026-10-18 by Claude.
- ✅ Should `op-code` also show the branch diff against `main`?
  - Answer: No. `op-code` opens VS Code only, and the user reads the changes there (R17). Closed 2026-10-18 by the user.
- ✅ How does the check of `op-code` see that VS Code shows the workspace?
  - Answer: It does not ask VS Code. It confirms that `code` ran on the root of the git checkout and exited without an error (R21). The user sees the window at once, and a stronger check would need a workaround such as reading window titles. Closed 2026-10-18 by the user.

## Research questions

### User

None.

### Claude

- which folder a new cmux pane starts in when the session entered a worktree after it started. (R20)
