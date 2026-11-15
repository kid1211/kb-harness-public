# Worktree end: detailed requirements

## Requirements

- ✅ **R1. Preserved before removed:** a worktree is removed only if its PR is merged, it has no commits beyond the default branch, or the user typed `delete`. Invariant `removedImpliesPreserved` in `worktree-end.qnt`.
  - Serves: F2
- ✅ **R2. Merge goes through a PR:** a merge pushes the branch and uses a PR on `origin`. There is no local merge. Invariants `remoteRemovalRequiresPush` and `mergedRequiresInSync`.
  - Serves: F1
- ✅ **R3. A blocked merge stays put:** if GitHub refuses a merge-now, the session stays in the worktree. It says why, and offers to sync with `worktree-sync`, fix, push and merge again. Invariant `blockedStaysInWorktree`.
  - Serves: F1
- ✅ **R4. Land on the default branch:** after ExitWorktree, a clean primary checkout goes to the default branch. Invariant `onDefaultRequiresExited`.
  - Serves: F1
- ✅ **R5. Scripts, not prose:** `scripts/wt-end.sh` runs every git and gh step and prints one line with a verdict word. Git and gh output shows only on failure.
  - Serves: F3
- ✅ **R6. Skill is execution only:** the skill folder holds `SKILL.md` and `scripts/`. The model is in this plan. The tests are in `tests/skills/worktree-end/`.
  - Serves: F3
- ✅ **R7. Typed confirmation:** only the literal word `delete` confirms a discard of commits or a forced removal. A rejected question is not an answer. Every invocation starts at Step 0. No check covers these. The skill states them.
  - Serves: F2
- ✅ **R8. Merge now commits first:** if the worktree has uncommitted changes and the user picks Merge now, the skill commits them by path, then merges. Any other choice still stops on uncommitted changes. The model still ends at `blocked_dirty`, so no invariant covers it.
  - Serves: F1
- ✅ **R9. Ask for a retro:** [implement] after each ExitWorktree call, the skill asks the user "Run a session retro?", yes or no. A yes starts the `session-retro` run in the background. A no starts nothing. The retro is outside this model, so no invariant covers it.
  - Serves: F3
