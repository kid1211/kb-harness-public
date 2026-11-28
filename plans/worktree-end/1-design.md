# Worktree end: design

## State transitions

- The model is [worktree-end.qnt](worktree-end.qnt). Module `worktreeEndLifecycle` is the lifecycle. Module `worktreeEndLifecycleBuggy` is a copy with five wrong moves, one per invariant. The test fixtures come from its counterexamples.
- The graph in `architecture.md` is the source of truth. Each state node is a value of the var `phase`, and a heading of `SKILL.md` once it is built. `wt_end_sh` is the script `.claude/skills/worktree-end/scripts/wt-end.sh`. It is not modelled.
- The model keeps the facts of the worktree in vars: `hasCommits`, `pushed`, `inSync`, `merged`, `removed`, `kept`, `onDefault`, `discardConfirmed`.

```graph
import-graph: architecture.md
```

1. [start](#start): the run begins. The user picks how the worktree ends.
2. [blocked_dirty](#blocked_dirty): uncommitted changes, and the choice is not Merge now.
3. [switch_confirm](#switch_confirm): The user chose to leave without a merge.
4. [switched](#switched): The user confirmed. The worktree is kept.
5. [discard_confirm](#discard_confirm): The user chose to discard a worktree with commits.
6. [discard_kept](#discard_kept): the discard is confirmed, and ExitWorktree would not remove.
7. [discarded](#discarded): the worktree is removed with its commits.
8. [empty_kept](#empty_kept): no commits, and ExitWorktree would not remove.
9. [empty_removed](#empty_removed): no commits, and the worktree is removed.
10. [merge_now_check](#merge_now_check): the branch is pushed and the PR merge is tried.
11. [merge_blocked](#merge_blocked): GitHub refused the merge.
12. [remote_check](#remote_check): the pushed branch is checked against its PR.
13. [remote_waiting](#remote_waiting): the PR is open, and the worktree is kept.
14. [remote_kept](#remote_kept): the PR is merged, and ExitWorktree would not remove.
15. [remote_removed](#remote_removed): the PR is merged, and the worktree is removed.
16. [force_removed](#force_removed): removed by hand after a typed `delete`.

## State deep dive

### start

`S status` reads the worktree (`init`). The user picks Merge, Merge now, Switch away or Discard. A worktree with no commits and a worktree with commits take different ways (`chooseMergeEmpty`, `chooseMergeNonEmpty`). `landOnDefault` runs after any ExitWorktree call.

- **Invariants:** `removedImpliesPreserved`, `onDefaultRequiresExited`.
- **Expected output:** one status line. `S status` prints `DIRTY` for uncommitted changes.

### blocked_dirty

Uncommitted changes, and the user did not pick Merge now (`blockDirty`). The run stops. No ExitWorktree call is made.

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** the dirty files shown to the user. `blockedDirtyTest` reaches it with nothing kept or removed.

### switch_confirm

The skill asks "Leave without merging?" (`intentSwitch`). A no goes back to start (`declineSwitch`).

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** one question to the user.

### switched

The user confirmed (`confirmSwitch`). `ExitWorktree(keep)` runs and the worktree stays with its commits.

- **Invariants:** `removedImpliesPreserved`, `onDefaultRequiresExited`.
- **Expected output:** the worktree kept. `switchedTest`.

### discard_confirm

The user chose Discard on a worktree with commits (`intentDiscard`). Only the typed word `delete` goes on. Any other answer goes back to start (`declineDiscard`).

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** a request to type `delete`.

### discard_kept

The discard is confirmed, but `ExitWorktree(remove)` refused because this session did not make the worktree (`confirmDiscardOwnershipBlocked`). `discardConfirmed` is true.

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** the worktree kept, with an offer of a forced removal.

### discarded

The typed `delete` removes the worktree with its commits (`confirmDiscard`). It is the one removal with commits and no merge, and it needs `discardConfirmed`.

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** the worktree removed. `discardedTest`.

### empty_kept

The worktree has no commits, and `ExitWorktree(remove)` refused on ownership (`chooseMergeEmptyOwnershipBlocked`).

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** the worktree kept, with an offer of a forced removal.

### empty_removed

The worktree has no commits, so there is nothing to push or keep (`chooseMergeEmpty`). It is removed.

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** the worktree removed. `emptyRemovedTest`.

### merge_now_check

Merge now commits what is dirty, pushes the branch and merges the PR in one run (`chooseMergeNow`). The branch is pushed and in sync. GitHub accepts the merge (`mergeNowAccepted`) or refuses it (`mergeNowBlocked`).

- **Invariants:** `remoteRemovalRequiresPush`, `mergedRequiresInSync`.
- **Expected output:** one line with the verdict of the merge.

### merge_blocked

GitHub refused the merge. The session stays in the worktree. It says why, and offers a rebase onto `origin/<default>` by hand, a fix, a push and another merge (`fixBlocked`).

- **Invariants:** `blockedStaysInWorktree`.
- **Expected output:** the reason GitHub gave. Neither `kept` nor `removed` is set.

### remote_check

The branch is pushed or about to be. The script checks the PR on origin. Each outcome is a move: first push (`pushRemote`), new commits (`pushUpdate`), merged (`remoteFoundMerged`), merged but remove refused (`remoteFoundMergedOwnershipBlocked`), not merged (`remoteFoundNotMerged`).

- **Invariants:** `remoteRemovalRequiresPush`, `mergedRequiresInSync`.
- **Expected output:** one line with the verdict word of the check.

### remote_waiting

The PR is open and the worktree is kept. A later run checks again (`retryRemoteCheck`) when the tip is unchanged. New commits during the wait set `inSync` false (`driftWhileWaiting`), and the next check pushes them.

- **Invariants:** `mergedRequiresInSync`.
- **Expected output:** the worktree kept, with the PR link.

### remote_kept

The PR is merged, but `ExitWorktree(remove)` refused on ownership. The worktree is kept. A typed `delete` offers a forced removal (`confirmForceRemove`).

- **Invariants:** `removedImpliesPreserved`, `remoteRemovalRequiresPush`.
- **Expected output:** the worktree kept, with an offer of a forced removal.

### remote_removed

The PR is merged and the worktree is removed (`remoteFoundMerged`).

- **Invariants:** `removedImpliesPreserved`, `remoteRemovalRequiresPush`, `mergedRequiresInSync`.
- **Expected output:** the worktree removed. `remoteRemovedTest`.

### force_removed

The typed `delete` runs `git worktree remove --force` and `git branch -D` (`confirmForceRemove`). It is reachable only from the three kept states, and each of them already holds the premise of `removedImpliesPreserved`.

- **Invariants:** `removedImpliesPreserved`.
- **Expected output:** the worktree and its branch removed. `forceRemovedTest`.

## Build checks

The level builds the skill `.claude/skills/worktree-end/` and its tests in `tests/skills/worktree-end/`.

- **State check:** `tests/skills/worktree-end/check-state.sh` tests the nine variables of a state against the invariants. `tests/skills/worktree-end/test-model.sh` feeds it states from a trace of `worktreeEndLifecycle`, which must pass, and from a counterexample of `worktreeEndLifecycleBuggy`, which must fail.
- **Output check:** `tests/skills/worktree-end/test-wt-end.sh` runs `.claude/skills/worktree-end/scripts/wt-end.sh` against real git repos and a stub `gh`.
- **Flow check:** `design-check.py flow`: each state node is a state of the model, a `###` above, and a heading of the built `SKILL.md`.
- **Invariants:** `removedImpliesPreserved`, `remoteRemovalRequiresPush`, `mergedRequiresInSync`, `onDefaultRequiresExited` and `blockedStaysInWorktree`. Each has a run that checks it along 8 random moves: `removedImpliesPreservedTest`, `remoteRemovalRequiresPushTest`, `mergedRequiresInSyncTest`, `onDefaultRequiresExitedTest`, `blockedStaysInWorktreeTest`. `neverRemoved` is the negative control.
- **Model tests:** `blockedDirtyTest`, `switchedTest`, `emptyRemovedTest`, `remoteRemovedTest`, `forceRemovedTest`, `discardedTest`.
- **Not checked by a script:** the typed word `delete`, a rejected question, and the commit of dirty files by Merge now. Only a session shows them. The skill states them.
- **Removal check:** `tests/skills/worktree-end/test-no-worktree-sync.sh` fails if the skill folder or its end-to-end cases exist, or if a live file names `worktree-sync`. It skips the records of the past: `alt-` files, changelogs, the fixtures of `spec`, and `plans/release-video/`, which changes in its own round.
- **No file is left** by any state. The worktree and its branch are the state, and `check-state.sh` reads them.

## Coverage

| Requirement | Held by |
|---|---|
| R1 | `buggyRemoveWithoutMerge`, `chooseMergeEmpty`, `chooseMergeEmptyOwnershipBlocked`, `confirmSwitch`, `declineSwitch`, `done`, `emptyRemovedTest`, `intentSwitch`, `removedImpliesPreserved`, `removedImpliesPreservedTest`, `switchedTest` |
| R2 | `buggyMergeWhileDiverged`, `buggyMergeWithoutPush`, `chooseMergeNonEmpty`, `chooseMergeNow`, `driftWhileWaiting`, `mergeNowAccepted`, `mergedRequiresInSync`, `mergedRequiresInSyncTest`, `pushRemote`, `pushUpdate`, `remoteFoundMerged`, `remoteFoundMergedOwnershipBlocked`, `remoteFoundNotMerged`, `remoteRemovalRequiresPush`, `remoteRemovalRequiresPushTest`, `remoteRemovedTest`, `retryRemoteCheck` |
| R10 | `blockedStaysInWorktree`, `blockedStaysInWorktreeTest`, `buggyExitOnBlocked`, `fixBlocked`, `mergeNowBlocked` |
| R4 | `buggyLandWithoutExit`, `landOnDefault`, `onDefaultRequiresExited`, `onDefaultRequiresExitedTest` |
| R5 | `.claude/skills/worktree-end/scripts/wt-end.sh` prints one line with a verdict word. Not in the model: `test-wt-end.sh` checks it |
| R6 | The skill folder holds `SKILL.md` and `scripts/`. Not in the model: a layout rule of the build |
| R7 | `confirmDiscard`, `confirmDiscardOwnershipBlocked`, `confirmForceRemove`, `declineDiscard`, `discardedTest`, `forceRemovedTest`, `intentDiscard`. The typed word itself is not in the model: only a session shows it, and the skill states it |
| R8 | `blockDirty`, `blockedDirtyTest`. The model ends at blocked_dirty, so no invariant covers the commit that Merge now makes |
| R9 | The retro question comes after ExitWorktree, outside this model. The skill states it |
| R11 | Not in the model: no state names a skill. `tests/skills/worktree-end/test-no-worktree-sync.sh` checks that no live file names `worktree-sync` |
| blocked_dirty | `blockedDirtyTest` |
| switched | `switchedTest` |
| empty_removed | `emptyRemovedTest` |
| remote_removed | `remoteRemovedTest` |
| force_removed | `forceRemovedTest` |
| discarded | `discardedTest` |

## Risks

- **The model is one lifecycle, not one model per rule.** The facets share state, so one machine holds them all. A new choice needs a new action, and each invariant is checked again.
- **The model cannot read a typed word.** `confirmForceRemove` and `confirmDiscard` are guarded as if the word was typed. The skill carries the rule, and a session test is the only check.
- **Git and GitHub are outside the model.** Real conflicts, refused merges and ownership refusals are inputs to it. `test-wt-end.sh` runs the script against real repos and a stub `gh`.
- **The buggy module is a copy.** A change to an action of `worktreeEndLifecycle` needs the same change there.

## Appendix

- The model checks, from the harness root:

  ```sh
  npx quint test plans/worktree-end/worktree-end.qnt --main=worktreeEndLifecycle
  npx quint run plans/worktree-end/worktree-end.qnt --main=worktreeEndLifecycle --invariant=removedImpliesPreserved
  npx quint run plans/worktree-end/worktree-end.qnt --main=worktreeEndLifecycle --invariant=neverRemoved   # must report a violation
  ```

- The test suites: `bash tests/skills/worktree-end/test-wt-end.sh` and `bash tests/skills/worktree-end/test-model.sh` (needs a JVM).
- The history of the model, one extension at a time, is in the header of `worktree-end.qnt`.
