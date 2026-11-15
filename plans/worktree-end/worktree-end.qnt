// The worktree-end lifecycle: deciding whether it's safe to call ExitWorktree(remove).
//
// The gate in `spec-quint` classified 13 stated requirements: 11 transition, 0
// configuration, 2 prose (deriving the target branch fresh rather than from memory;
// the local option's label showing the branch name — both agent conventions with no
// mechanical check). This models the transition rows as ONE state machine, not
// separate models — they are facets of a single lifecycle, not independent
// requirements. That is unusual for a skill (the norm is zero transition rows,
// per `references/specifying-a-skill.md`); confirmed with the user before writing
// this rather than assumed.
//
// Extended after first landing: switching (leaving without merging) is no longer a
// bare, frictionless choice. It now gates on an explicit "are you sure you want to
// leave without merging? consider opening a new session instead" confirmation —
// decline loops back to the top-level merging/switching question rather than
// silently proceeding. Added as actions to the existing state machine (intentSwitch
// / confirmSwitch / declineSwitch), not a rewrite; all pre-existing invariants
// re-verified after the change, not just what's new.
//
// Simplified after a live test run against a real scratch worktree (2026-09-15):
// the local-merge sub-machine (`decideRemoteLocal`/`localConfirm`/`localMerging`/
// conflict handling) is gone, on the user's direction — a local merge is a rare
// path with real extra complexity (the primary-checkout sandbox restriction the
// old Step 5b had to work around), so merging a worktree now ALWAYS goes through
// a pushed branch + PR. That also removes `targetIsMain` as a variable: it only
// ever gated the remote-vs-local choice, which no longer exists — a PR can target
// any branch, default or not, so there is nothing left to branch on before
// `remoteCheck`. `mergedVia`'s tri-state collapses to a plain `merged: bool`,
// since there is only one route to it now. The rule "main is never a local-merge
// target" (`neverLocalMergeIntoMain`) is dropped rather than kept vacuously true —
// an invariant that can never be violated because its premise is unreachable
// is not evidence of anything, so it does not belong in `run`/`verify` either.
//
// Extended again the same day: the re-entry check (`remoteCheck` on a later
// invocation) was collapsing two different situations into one branch. It ran
// the "is this merged yet" check unconditionally on whatever the local branch
// tip happened to be, with no check that the tip still matched what was last
// pushed. If the worktree picked up new commits after the initial push (the
// user kept working in it between invocations), the old logic would just read
// that as "not merged yet, keep waiting" — true, but misleading: the real
// state is "there's new work the PR has never seen," which calls for pushing
// again, not waiting. `inSync` makes that a real branch: `pushRemote` and the
// new `pushUpdate` both set it true (this push reflects the current local
// tip); the new `driftWhileWaiting` sets it false (more local commits landed
// during the wait); `remoteFoundMerged`/`remoteFoundNotMerged` now require it.
//
// Extended a third time (2026-09-15), from a live report: a worktree with a
// clean working tree but ZERO commits beyond its base was still being asked
// "merging or switching?" as if there were something to push — there isn't.
// `hasCommits` makes that fact observable, fixed at the merge/switch choice
// like `targetIsMain` used to be. Choosing merge on an empty worktree
// (`chooseMergeEmpty`) skips the whole push/PR machinery and removes directly
// — there's nothing to preserve, so nothing is lost. That forced a real change
// to `removedImpliesPreserved`: "preserved" now reads as "merged, or there was
// never anything here to begin with" instead of just "merged".
//
// Extended a fourth time (2026-09-15), after a report that a worktree session
// left the primary checkout on whatever branch it happened to be on before
// `EnterWorktree` was ever called, rather than the repo's default branch.
// `onDefault` makes "the primary checkout is back on the default branch"
// observable, and `landOnDefault` is the one new action: it can fire once
// `kept or removed` is true (i.e. `ExitWorktree` has actually fired) and
// `onDefault` isn't already true. The dirty-primary-checkout case is
// deliberately NOT a second action — the skill's response to finding the
// primary checkout dirty is "don't switch, tell the user, stop," which changes
// no variable at all, making it indistinguishable from the existing `done`
// self-loop. Adding a same-effect action would be a hollow branch, not a real
// one. `onDefaultRequiresExited` is the one property this makes checkable:
// the primary checkout is never claimed to be back on default before
// `ExitWorktree` genuinely fired — landing on default is not itself a
// substitute for going through the exit.
//
// Extended a fifth time (2026-09-15), from a live run that hit
// `ExitWorktree(remove)`'s own ownership refusal: a session that re-entered a
// worktree via `path` (or resumed after losing its creation lock) cannot
// remove it, full stop, independent of whether the merge/empty-worktree logic
// says removal is justified. `chooseMergeEmptyOwnershipBlocked` and
// `remoteFoundMergedOwnershipBlocked` add that outcome at both `remove` call
// sites — kept instead of removed, with `merged`/`hasCommits` left exactly as
// they were (the underlying fact — was there anything to merge, did the merge
// happen — doesn't change just because cleanup couldn't). No new invariant:
// every existing one already covers a `kept and not removed` state (that
// shape already exists via `remoteFoundNotMerged`), and both new actions
// re-verify NoError against all four.
//
// Extended a sixth time (2026-09-17), on direct instruction: the ownership-blocked
// fallback used to be a dead end — kept on disk, with manual removal left entirely to
// the user's own later initiative outside this skill. Now the skill itself offers a
// guarded manual path out of it: ask for an explicit typed "delete" (not a yes/no
// AskUserQuestion — that would undercut the friction this confirmation exists for),
// then run `git worktree remove --force` and `git branch -D` directly, since the
// session is already back in the primary checkout after the ExitWorktree(keep) that
// preceded the ownership refusal (confirmed empirically: ExitWorktree itself will not
// remove a worktree this session doesn't own, full stop, regardless of how explicit
// the instruction is — that restriction is what this path routes around, deliberately,
// with a human in the loop). `confirmForceRemove` is the one new action: it only fires
// from `emptyKept` or `remoteKept`, the two phases the ownership-blocked actions above
// land in — and both already pin the fact `removedImpliesPreserved` cares about
// (`emptyKept`: hasCommits is false; `remoteKept`: merged is already true) before
// `confirmForceRemove` can ever run. So the new transition cannot bypass preservation;
// it needed no new invariant, only re-verification that all four still hold with it in
// the action set. The typed-word requirement itself is not modelable — same category as
// the rejected-question rule — and is recorded in "What isn't mechanically checked"
// instead.
//
// Extended a seventh time (2026-09-17), on direct instruction: the top-level question
// was merge-or-switch only — there was no way to say "throw this away," so discarding a
// worktree with real commits meant either merging it anyway or leaving it kept on disk
// forever. Added "discard and remove" as a third top-level choice (`intentDiscard`), on
// commits that already exist — the empty case is unchanged, since `chooseMergeEmpty`
// already removes a worktree with nothing to lose and a separate discard path for it
// would be a distinction without a difference. A real discard destroys commits on
// purpose, which is exactly the state `removedImpliesPreserved` exists to rule out, so
// this could not be another action landing in the same invariant — the invariant itself
// had to gain a named, narrow escape hatch: the new `discardConfirmed` var, set true by
// exactly one action (`confirmDiscard`), gated on the same typed-literal-word confirmation
// as the sixth extension's force-removal path (not an AskUserQuestion click — seen there
// to undercut the friction on purpose). The ownership-refusal case
// (`confirmDiscardOwnershipBlocked`) reuses `confirmForceRemove` rather than duplicating
// it — `discardKept` was added to that action's existing guard alongside `emptyKept` and
// `remoteKept`, since all three already pin `removedImpliesPreserved`'s premise before it
// can fire (the first two structurally, this one via `discardConfirmed`). No invariant
// needed to change shape, only to admit the one deliberate exception; all four were
// re-verified against both the widened real module and its buggy sibling.
//
// The property this exists to check: a worktree is only ever removed once its work
// is verifiably preserved elsewhere — pushed, in sync with the local tip, then
// confirmed merged into the branch it targeted on origin — or once it's established
// there was no work to preserve in the first place — or once the user has explicitly,
// typed-word confirmed throwing it away on purpose — and the primary checkout is
// never reported as landed on the default branch without `ExitWorktree` having
// actually run. `ExitWorktree`'s own safety net (the `discard_changes` check) only
// catches "would this lose uncommitted/unmerged work" at the moment of the call; it
// has no notion of "was this actually merged where the user wanted" or "did the
// primary checkout genuinely change branches", which is entirely on the skill, and
// is what these invariants check.
//
// Extended an eighth time (2026-10-18), on direct instruction: a "merge now"
// option for small work. `chooseMergeNow` pushes and merges the PR in the same
// invocation, then reuses the remoteCheck outcomes. No new variable and no
// invariant changed.
//
// Extended a ninth time (2026-10-20), on direct instruction: a merge-now that
// GitHub blocks stays in the worktree (`mergeNowBlocked`), so the user can sync, fix
// and merge again (`fixBlocked`). New invariant: `blockedStaysInWorktree`.
//
// Readings pinned after the Step 3 checkpoint (confirmed with the user):
//   - dirty/switch/conflict/remote-merged are modelled as action branches (which
//     transition fires), not as separate nondet vars — the structure of the state
//     machine IS the fact pattern.
//   - "already pushed" (remote re-entry) reads as the upstream tracking ref being
//     set (`git rev-parse @{u}` succeeds), modelled as the `pushed` var.
//   - "in sync" reads as the local branch tip equalling `<branch>@{u}`
//     (`git rev-parse <branch>` vs `git rev-parse <branch>@{u}`), modelled as the
//     `inSync` var.
//   - "has commits" reads as `git rev-list --count origin/<default>..HEAD` being
//     nonzero, modelled as the `hasCommits` var, fixed at the merge/switch choice.
//   - "on default" reads as a successful `git checkout <default-branch>` in the
//     primary checkout after `ExitWorktree`, modelled as the `onDefault` var.
//   - the dirty-block ends the trace with neither `removed` nor `kept` set —
//     nothing was called, the worktree is left exactly as it was, matching "no
//     ExitWorktree call".

module worktreeEndLifecycle {
  var phase: str
  // Does this branch have any commits beyond its base? Fixed once, at the
  // merge/switch choice — observed, not chosen.
  var hasCommits: bool
  // Has this branch already been pushed (upstream tracking ref set)?
  var pushed: bool
  // Does the local branch tip still match what was last pushed (<branch>@{u})?
  // Meaningless before the first push; both actions that push it set it true.
  var inSync: bool
  // Has the pushed, in-sync branch been confirmed merged into what it targeted
  // on origin?
  var merged: bool
  // Has the worktree been removed — either ExitWorktree(remove) fired, or a
  // manual forced removal (git worktree remove --force + git branch -D) ran
  // after ExitWorktree(remove) refused on ownership grounds and the user
  // typed "delete" to confirm it anyway.
  var removed: bool
  // Has ExitWorktree(keep) fired. Not mutually exclusive with removed — a trace
  // calls keep after the first push, then remove once verified merged later.
  var kept: bool
  // Has the primary checkout been switched onto the default branch, after
  // ExitWorktree fired and the primary checkout was found clean.
  var onDefault: bool
  // Has the user explicitly confirmed discarding real commits — typed
  // "delete" in response to the discard confirmation, not clicked an
  // AskUserQuestion option. The one deliberate exception to
  // `removedImpliesPreserved`: a worktree with real commits can be removed
  // unpreserved, but only once this is true, never as a side effect of any
  // other action.
  var discardConfirmed: bool

  action init = all {
    phase' = "start",
    hasCommits' = false,
    pushed' = false,
    inSync' = false,
    merged' = false,
    removed' = false,
    kept' = false,
    onDefault' = false,
    discardConfirmed' = false,
  }

  // R1. Dirty worktree blocks everything. Terminal: no ExitWorktree call.
  /// R8: uncommitted changes stop every choice but Merge now. No ExitWorktree call.
  action blockDirty = all {
    phase == "start",
    phase' = "blocked_dirty",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // R2. Switching now gates on an explicit "are you sure you want to leave without
  // merging? consider opening a new session instead" confirmation before it fires
  // — it is no longer a bare, frictionless choice from `start`.
  /// R1: leaving without merging first asks for a confirm. Nothing is lost.
  action intentSwitch = all {
    phase == "start",
    phase' = "switch_confirm",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Confirmed: keep, nothing else. Terminal.
  /// R1: a confirmed leave keeps the worktree.
  action confirmSwitch = all {
    phase == "switch_confirm",
    phase' = "switched",
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Declined: back to the top-level question. No side effects.
  /// R1: a declined leave goes back to the first question.
  action declineSwitch = all {
    phase == "switch_confirm",
    phase' = "start",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Merging an empty worktree — no commits beyond its base — has nothing to
  // push or preserve. Remove directly, no push/PR machinery, no ExitWorktree(keep)
  // stop-and-wait: there is nothing to wait on.
  /// R1: a worktree with no commits has nothing to keep, so it is removed.
  action chooseMergeEmpty = all {
    phase == "start",
    hasCommits' = false,
    phase' = "empty_removed",
    removed' = true,
    pushed' = pushed, inSync' = inSync, merged' = merged, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // ExitWorktree(remove) can refuse on ownership grounds alone (this session
  // re-entered the worktree via `path`, or resumed after losing its own
  // creation lock) — independent of whether removal is otherwise justified.
  // Falls back to kept, not removed; the empty-worktree fact itself doesn't
  // change.
  /// R1: ExitWorktree refuses to remove a worktree this session did not make. It is kept.
  action chooseMergeEmptyOwnershipBlocked = all {
    phase == "start",
    hasCommits' = false,
    phase' = "empty_kept",
    kept' = true,
    pushed' = pushed, inSync' = inSync, merged' = merged, removed' = removed,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // R4. Merging a worktree with real commits always goes through the remote/PR
  // route — no branch on the target here, because there is nothing left to
  // branch on: local is gone.
  /// R2: a worktree with commits merges through a pushed branch and a PR.
  action chooseMergeNonEmpty = all {
    phase == "start",
    hasCommits' = true,
    phase' = "remote_check",
    pushed' = pushed, inSync' = inSync, merged' = merged, removed' = removed, kept' = kept,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // "Merge now": push, open the PR and merge it in one invocation, for small
  // work. Lands in remoteCheck pushed and in sync, so the existing
  // remoteFoundMerged / ownership-blocked / not-merged actions decide the
  // outcome: a merge that failed reads as not merged, and the worktree is kept.
  /// R2: Merge now pushes and merges the PR in one run.
  action chooseMergeNow = all {
    phase == "start",
    hasCommits' = true,
    phase' = "merge_now_check",
    pushed' = true,
    inSync' = true,
    merged' = merged, removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // `gh pr merge` accepted the merge: the remoteCheck outcomes follow.
  /// R2: GitHub took the merge. The checks of a pushed branch follow.
  action mergeNowAccepted = all {
    phase == "merge_now_check",
    phase' = "remote_check",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // GitHub refused the merge (a conflict, a failed check, a branch behind its
  // base). The session stays in the worktree: no ExitWorktree call.
  /// R3: GitHub refused the merge. The session stays in the worktree.
  action mergeNowBlocked = all {
    phase == "merge_now_check",
    phase' = "merge_blocked",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // The user syncs onto the default branch and fixes it in the worktree. The new
  // commits are not pushed yet, so the next invocation starts over.
  /// R3: The user fixes the worktree. The new commits are not pushed yet.
  action fixBlocked = all {
    phase == "merge_blocked",
    phase' = "start",
    inSync' = false,
    hasCommits' = hasCommits, pushed' = pushed, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // R6. First entry: not pushed yet. Push, keep, wait.
  /// R2: first push of the branch. The worktree is kept and waits for the merge.
  action pushRemote = all {
    phase == "remote_check",
    not(pushed),
    phase' = "remote_waiting",
    pushed' = true,
    inSync' = true,
    kept' = true,
    hasCommits' = hasCommits, merged' = merged, removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // R7. worktree-end run again later, local tip unchanged since the last push:
  // go re-check.
  /// R2: a later run with the tip unchanged checks the PR again.
  action retryRemoteCheck = all {
    phase == "remote_waiting",
    inSync,
    phase' = "remote_check",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // New work landed in the worktree during the wait: the local tip no longer
  // matches what was pushed. Surfaces on the next re-check as "diverged", not
  // silently folded into "not merged yet".
  /// R2: new commits land while the PR waits. The tip no longer matches the push.
  action driftWhileWaiting = all {
    phase == "remote_waiting",
    inSync,
    phase' = "remote_waiting",
    inSync' = false,
    hasCommits' = hasCommits, pushed' = pushed, merged' = merged, removed' = removed,
    kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Re-check finds the tip has drifted from what was pushed: push the new work,
  // not a merge verdict on stale content. Same shape as the initial push, minus
  // the "not pushed yet" guard.
  /// R2: the tip drifted, so the new commits are pushed before any merge check.
  action pushUpdate = all {
    phase == "remote_check",
    pushed,
    not(inSync),
    phase' = "remote_waiting",
    inSync' = true,
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, merged' = merged, removed' = removed,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // R7. Pushed, tip matches what's on origin, and it turns out to be merged: remove.
  /// R2: the pushed, in-sync branch is merged on origin, so the worktree is removed.
  action remoteFoundMerged = all {
    phase == "remote_check",
    pushed,
    inSync,
    phase' = "remote_removed",
    removed' = true,
    merged' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, kept' = kept,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Same ownership refusal as chooseMergeEmptyOwnershipBlocked, on the other
  // ExitWorktree(remove) call site. The merge genuinely happened (merged'
  // still becomes true — that fact doesn't depend on whether the worktree
  // could be cleaned up) but removal itself didn't.
  /// R2: merged, but ExitWorktree refuses to remove. The worktree is kept.
  action remoteFoundMergedOwnershipBlocked = all {
    phase == "remote_check",
    pushed,
    inSync,
    phase' = "remote_kept",
    kept' = true,
    merged' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, removed' = removed,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // R7. Pushed, tip matches what's on origin, not merged yet: report, keep waiting.
  /// R2: the pushed branch is not merged yet. Report it and keep waiting.
  action remoteFoundNotMerged = all {
    phase == "remote_check",
    pushed,
    inSync,
    phase' = "remote_waiting",
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // After an ownership refusal, a guarded manual path: the user types "delete"
  // (modelled here as the guard on entering this action at all — the literal
  // string match itself is not something this model can express, see
  // SKILL.md's "What isn't mechanically checked"), then `git worktree remove
  // --force` + `git branch -D` run directly, since the session is already
  // back in the primary checkout from the ExitWorktree(keep) that preceded
  // the refusal. Reachable from the two merge-side ownership-blocked phases,
  // both of which already pin removedImpliesPreserved's premise before this
  // can fire, and from `discardKept` (the ownership-blocked discard fallback
  // below), which pins it via `discardConfirmed` instead — so this cannot
  // become a bypass of that guarantee from any of the three.
  /// R7: after a refused remove, only the typed word delete forces the removal.
  action confirmForceRemove = all {
    (phase == "empty_kept") or (phase == "remote_kept") or (phase == "discard_kept"),
    phase' = "force_removed",
    removed' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Chose "discard and remove" at the top-level question, on a worktree with
  // real commits (the empty case is indistinguishable from `chooseMergeEmpty`
  // — nothing exists to discard beyond what that action already removes, so
  // it is not modelled separately here). Observes `hasCommits' = true` the
  // same way `chooseMergeNonEmpty` does, then waits for the destructive
  // confirmation below rather than removing on the spot.
  /// R7: discard of a worktree with commits waits for a typed confirm.
  action intentDiscard = all {
    phase == "start",
    hasCommits' = true,
    phase' = "discard_confirm",
    pushed' = pushed, inSync' = inSync, merged' = merged, removed' = removed,
    kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Declined: back to the top-level question, no side effects — same shape
  // as declineSwitch.
  /// R7: a declined discard goes back to the first question.
  action declineDiscard = all {
    phase == "discard_confirm",
    phase' = "start",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // Confirmed with the typed literal "delete" (not an AskUserQuestion click —
  // see SKILL.md's "What isn't mechanically checked"): removes with real
  // commits present and merged left false. This is the one place
  // `removedImpliesPreserved`'s exception is actually exercised on purpose;
  // `discardConfirmed' = true` is what lets it satisfy the invariant instead
  // of violating it.
  /// R7: the typed word delete removes a worktree with commits.
  action confirmDiscard = all {
    phase == "discard_confirm",
    phase' = "discarded",
    removed' = true,
    discardConfirmed' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    kept' = kept, onDefault' = onDefault,
  }

  // Same ownership refusal as chooseMergeEmptyOwnershipBlocked and
  // remoteFoundMergedOwnershipBlocked, on the discard call site.
  // `discardConfirmed' = true` still fires — the user's confirmation is real
  // independent of whether cleanup could complete — landing in `discardKept`,
  // from which `confirmForceRemove` above offers the same guarded manual path
  // as the other two ownership-blocked phases.
  /// R7: the discard is confirmed, but ExitWorktree refuses. The worktree is kept.
  action confirmDiscardOwnershipBlocked = all {
    phase == "discard_confirm",
    phase' = "discard_kept",
    kept' = true,
    discardConfirmed' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
  }

  // Step 5. Once ExitWorktree has genuinely fired (kept or removed) and the
  // primary checkout hasn't already been landed on default, land it there.
  // Fires from whatever phase the trace is in — it doesn't depend on phase,
  // only on kept/removed — matching "runs after every ExitWorktree call
  // above." The dirty-primary-checkout outcome is intentionally not a
  // separate action: see the header note.
  /// R4: after ExitWorktree, a clean primary checkout goes to the default branch.
  action landOnDefault = all {
    kept or removed,
    not(onDefault),
    onDefault' = true,
    phase' = phase, hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync,
    merged' = merged, removed' = removed, kept' = kept,
    discardConfirmed' = discardConfirmed,
  }

  // Terminal self-loop, unconditional (as in the house `capacity` example) — without
  // it the checker reports a deadlock the instant a branch completes, which is a
  // modelling artifact and not a finding.
  /// R1: an end state stays as it is.
  action done = all {
    phase' = phase, hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync,
    merged' = merged, removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  action step = any {
    blockDirty, intentSwitch, confirmSwitch, declineSwitch,
    chooseMergeEmpty, chooseMergeEmptyOwnershipBlocked, chooseMergeNonEmpty, chooseMergeNow,
    mergeNowAccepted, mergeNowBlocked, fixBlocked,
    pushRemote, retryRemoteCheck, driftWhileWaiting, pushUpdate,
    remoteFoundMerged, remoteFoundMergedOwnershipBlocked, remoteFoundNotMerged,
    confirmForceRemove,
    intentDiscard, declineDiscard, confirmDiscard, confirmDiscardOwnershipBlocked,
    landOnDefault,
    done,
  }

  // The core property: removal never happens without either a completed merge,
  // nothing having existed to merge in the first place, or the user having
  // explicitly confirmed discarding it. This is what ExitWorktree's own
  // discard_changes check cannot verify — it knows nothing about PRs, only
  // about uncommitted/unmerged state, and it has no notion of "the user meant
  // to throw this away on purpose" versus a silent side effect of some other
  // path.
  /// R1: a worktree is removed only if merged, empty or discarded by a typed confirm.
  val removedImpliesPreserved = removed implies (merged or not(hasCommits) or discardConfirmed)

  // A confirmed merge only ever follows a push.
  /// R2: a merge follows a push.
  val remoteRemovalRequiresPush = merged implies pushed

  // A confirmed merge never reflects a stale check against a tip that had
  // already drifted — the model's actions enforce this with the `inSync` guard
  // on remoteFoundMerged, and this checks that guard was not bypassed.
  /// R2: a merge is never checked against a drifted tip.
  val mergedRequiresInSync = merged implies inSync

  // The primary checkout is never reported as landed on the default branch
  // before ExitWorktree actually fired.
  /// R4: the primary checkout lands on the default branch only after ExitWorktree.
  val onDefaultRequiresExited = onDefault implies (kept or removed)

  // A merge that GitHub blocks never leaves the worktree.
  /// R3: a blocked merge never leaves the worktree.
  val blockedStaysInWorktree = (phase == "merge_blocked") implies not(kept or removed)

  // Removal does happen, on two success paths (remoteFoundMerged, chooseMergeEmpty). A
  // checker that reports the next val as holding is broken, and every green above it is worthless.
  // NEGATIVE CONTROL: false on purpose.
  /// R1: removal does happen on two success paths, so this fails.
  val neverRemoved = not(removed)

  /// R1: the invariant holds along 8 random moves.
  run removedImpliesPreservedTest = init.then(8.reps(_ => step)).expect(removedImpliesPreserved)
  /// R2: the invariant holds along 8 random moves.
  run remoteRemovalRequiresPushTest = init.then(8.reps(_ => step)).expect(remoteRemovalRequiresPush)
  /// R2: the invariant holds along 8 random moves.
  run mergedRequiresInSyncTest = init.then(8.reps(_ => step)).expect(mergedRequiresInSync)
  /// R4: the invariant holds along 8 random moves.
  run onDefaultRequiresExitedTest = init.then(8.reps(_ => step)).expect(onDefaultRequiresExited)
  /// R3: the invariant holds along 8 random moves.
  run blockedStaysInWorktreeTest = init.then(8.reps(_ => step)).expect(blockedStaysInWorktree)

  /// R8: the dirty-block ends with no ExitWorktree call.
  /// blocked_dirty
  run blockedDirtyTest = init.then(blockDirty).expect(phase == "blocked_dirty" and not(kept or removed))
  /// R1: a confirmed leave keeps the worktree.
  /// switched
  run switchedTest = init.then(intentSwitch).then(confirmSwitch).expect(phase == "switched" and kept and not(removed))
  /// R1: an empty worktree is removed.
  /// empty_removed
  run emptyRemovedTest = init.then(chooseMergeEmpty).expect(phase == "empty_removed" and removed and not(hasCommits))
  /// R2: a merged branch is removed.
  /// remote_removed
  run remoteRemovedTest = init.then(chooseMergeNow).then(mergeNowAccepted).then(remoteFoundMerged).expect(phase == "remote_removed" and merged and removed)
  /// R7: the typed word delete forces the removal after a refusal.
  /// force_removed
  run forceRemovedTest = init.then(chooseMergeEmptyOwnershipBlocked).then(confirmForceRemove).expect(phase == "force_removed" and removed)
  /// R7: the typed word delete discards a worktree with commits.
  /// discarded
  run discardedTest = init.then(intentDiscard).then(confirmDiscard).expect(phase == "discarded" and discardConfirmed and removed)
}

// ---------------------------------------------------------------------------
// A deliberately broken sibling, for spec-implement.
//
// `worktreeEndLifecycle` above VERIFIES all four real invariants — which means
// `quint verify` can never produce a counterexample against it: there is nothing
// wrong to find. But the checker's test suite needs a genuine FAIL fixture for
// each rule, sourced from the model checker's own exploration, never hand-authored
// (the same requirement research-artifacts/model.qnt's `faqAmendConsumes` exists
// to satisfy). This module is an exact copy of the real one, plus four stray
// actions, each isolated so it breaks exactly one invariant:
//
//   buggyRemoveWithoutMerge   — removes with hasCommits=true and merged left
//                               false: breaks removedImpliesPreserved. (Removing
//                               an empty worktree is NOT a bug — that's
//                               chooseMergeEmpty, a real action above — so this
//                               stray action has to explicitly claim there WAS
//                               something to preserve to actually be a bug.)
//   buggyMergeWithoutPush     — reaches merged=true from remoteCheck without
//                               pushed ever being set: breaks
//                               remoteRemovalRequiresPush
//   buggyMergeWhileDiverged   — reaches merged=true from remoteCheck while
//                               inSync is still false (a drifted tip): breaks
//                               mergedRequiresInSync. The other invariants
//                               stay true here (merged is set alongside removed,
//                               and pushed is already true), keeping them
//                               isolated.
//   buggyLandWithoutExit      — reaches onDefault=true from `start`, before
//                               ExitWorktree could possibly have fired: breaks
//                               onDefaultRequiresExited, isolated from the other
//                               three (kept and removed both stay false here).
//   buggyExitOnBlocked        — calls ExitWorktree(keep) on a merge that GitHub
//                               blocked: breaks blockedStaysInWorktree.
// ---------------------------------------------------------------------------

module worktreeEndLifecycleBuggy {
  // NEGATIVE CONTROL: the five buggy actions break one invariant each, on purpose.
  var phase: str
  var hasCommits: bool
  var pushed: bool
  var inSync: bool
  var merged: bool
  var removed: bool
  var kept: bool
  var onDefault: bool
  var discardConfirmed: bool

  action init = all {
    phase' = "start",
    hasCommits' = false,
    pushed' = false,
    inSync' = false,
    merged' = false,
    removed' = false,
    kept' = false,
    onDefault' = false,
    discardConfirmed' = false,
  }

  /// R8: uncommitted changes stop every choice but Merge now. No ExitWorktree call.
  action blockDirty = all {
    phase == "start",
    phase' = "blocked_dirty",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R1: leaving without merging first asks for a confirm. Nothing is lost.
  action intentSwitch = all {
    phase == "start",
    phase' = "switch_confirm",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R1: a confirmed leave keeps the worktree.
  action confirmSwitch = all {
    phase == "switch_confirm",
    phase' = "switched",
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R1: a declined leave goes back to the first question.
  action declineSwitch = all {
    phase == "switch_confirm",
    phase' = "start",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R1: a worktree with no commits has nothing to keep, so it is removed.
  action chooseMergeEmpty = all {
    phase == "start",
    hasCommits' = false,
    phase' = "empty_removed",
    removed' = true,
    pushed' = pushed, inSync' = inSync, merged' = merged, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R1: ExitWorktree refuses to remove a worktree this session did not make. It is kept.
  action chooseMergeEmptyOwnershipBlocked = all {
    phase == "start",
    hasCommits' = false,
    phase' = "empty_kept",
    kept' = true,
    pushed' = pushed, inSync' = inSync, merged' = merged, removed' = removed,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: a worktree with commits merges through a pushed branch and a PR.
  action chooseMergeNonEmpty = all {
    phase == "start",
    hasCommits' = true,
    phase' = "remote_check",
    pushed' = pushed, inSync' = inSync, merged' = merged, removed' = removed, kept' = kept,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: Merge now pushes and merges the PR in one run.
  action chooseMergeNow = all {
    phase == "start",
    hasCommits' = true,
    phase' = "merge_now_check",
    pushed' = true,
    inSync' = true,
    merged' = merged, removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // `gh pr merge` accepted the merge: the remoteCheck outcomes follow.
  /// R2: GitHub took the merge. The checks of a pushed branch follow.
  action mergeNowAccepted = all {
    phase == "merge_now_check",
    phase' = "remote_check",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // GitHub refused the merge (a conflict, a failed check, a branch behind its
  // base). The session stays in the worktree: no ExitWorktree call.
  /// R3: GitHub refused the merge. The session stays in the worktree.
  action mergeNowBlocked = all {
    phase == "merge_now_check",
    phase' = "merge_blocked",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  // The user syncs onto the default branch and fixes it in the worktree. The new
  // commits are not pushed yet, so the next invocation starts over.
  /// R3: The user fixes the worktree. The new commits are not pushed yet.
  action fixBlocked = all {
    phase == "merge_blocked",
    phase' = "start",
    inSync' = false,
    hasCommits' = hasCommits, pushed' = pushed, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: first push of the branch. The worktree is kept and waits for the merge.
  action pushRemote = all {
    phase == "remote_check",
    not(pushed),
    phase' = "remote_waiting",
    pushed' = true,
    inSync' = true,
    kept' = true,
    hasCommits' = hasCommits, merged' = merged, removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: a later run with the tip unchanged checks the PR again.
  action retryRemoteCheck = all {
    phase == "remote_waiting",
    inSync,
    phase' = "remote_check",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: new commits land while the PR waits. The tip no longer matches the push.
  action driftWhileWaiting = all {
    phase == "remote_waiting",
    inSync,
    phase' = "remote_waiting",
    inSync' = false,
    hasCommits' = hasCommits, pushed' = pushed, merged' = merged, removed' = removed,
    kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: the tip drifted, so the new commits are pushed before any merge check.
  action pushUpdate = all {
    phase == "remote_check",
    pushed,
    not(inSync),
    phase' = "remote_waiting",
    inSync' = true,
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, merged' = merged, removed' = removed,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: the pushed, in-sync branch is merged on origin, so the worktree is removed.
  action remoteFoundMerged = all {
    phase == "remote_check",
    pushed,
    inSync,
    phase' = "remote_removed",
    removed' = true,
    merged' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, kept' = kept,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: merged, but ExitWorktree refuses to remove. The worktree is kept.
  action remoteFoundMergedOwnershipBlocked = all {
    phase == "remote_check",
    pushed,
    inSync,
    phase' = "remote_kept",
    kept' = true,
    merged' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, removed' = removed,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: the pushed branch is not merged yet. Report it and keep waiting.
  action remoteFoundNotMerged = all {
    phase == "remote_check",
    pushed,
    inSync,
    phase' = "remote_waiting",
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R7: after a refused remove, only the typed word delete forces the removal.
  action confirmForceRemove = all {
    (phase == "empty_kept") or (phase == "remote_kept") or (phase == "discard_kept"),
    phase' = "force_removed",
    removed' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R7: discard of a worktree with commits waits for a typed confirm.
  action intentDiscard = all {
    phase == "start",
    hasCommits' = true,
    phase' = "discard_confirm",
    pushed' = pushed, inSync' = inSync, merged' = merged, removed' = removed,
    kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R7: a declined discard goes back to the first question.
  action declineDiscard = all {
    phase == "discard_confirm",
    phase' = "start",
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R7: the typed word delete removes a worktree with commits.
  action confirmDiscard = all {
    phase == "discard_confirm",
    phase' = "discarded",
    removed' = true,
    discardConfirmed' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    kept' = kept, onDefault' = onDefault,
  }

  /// R7: the discard is confirmed, but ExitWorktree refuses. The worktree is kept.
  action confirmDiscardOwnershipBlocked = all {
    phase == "discard_confirm",
    phase' = "discard_kept",
    kept' = true,
    discardConfirmed' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
  }

  /// R4: after ExitWorktree, a clean primary checkout goes to the default branch.
  action landOnDefault = all {
    kept or removed,
    not(onDefault),
    onDefault' = true,
    phase' = phase, hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync,
    merged' = merged, removed' = removed, kept' = kept,
    discardConfirmed' = discardConfirmed,
  }

  // --- The four stray actions ---

  /// R1: a wrong move on purpose: remove with commits and no merge.
  action buggyRemoveWithoutMerge = all {
    phase == "start",
    hasCommits' = true,
    phase' = "buggyRemoved",
    removed' = true,
    pushed' = pushed, inSync' = inSync, merged' = merged, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: a wrong move on purpose: merged with no push.
  action buggyMergeWithoutPush = all {
    phase == "remote_check",
    not(pushed),
    phase' = "remote_removed",
    removed' = true,
    merged' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, kept' = kept,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R2: a wrong move on purpose: merged while the tip drifted.
  action buggyMergeWhileDiverged = all {
    phase == "remote_check",
    pushed,
    not(inSync),
    phase' = "remote_removed",
    removed' = true,
    merged' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, kept' = kept,
    onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R3: a wrong move on purpose: exit after a blocked merge.
  action buggyExitOnBlocked = all {
    phase == "merge_now_check",
    phase' = "merge_blocked",
    kept' = true,
    hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync, merged' = merged,
    removed' = removed, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  /// R4: a wrong move on purpose: land on the default branch before ExitWorktree.
  action buggyLandWithoutExit = all {
    phase == "start",
    onDefault' = true,
    phase' = phase, hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync,
    merged' = merged, removed' = removed, kept' = kept,
    discardConfirmed' = discardConfirmed,
  }

  /// R1: an end state stays as it is.
  action done = all {
    phase' = phase, hasCommits' = hasCommits, pushed' = pushed, inSync' = inSync,
    merged' = merged, removed' = removed, kept' = kept, onDefault' = onDefault,
    discardConfirmed' = discardConfirmed,
  }

  action step = any {
    blockDirty, intentSwitch, confirmSwitch, declineSwitch,
    chooseMergeEmpty, chooseMergeEmptyOwnershipBlocked, chooseMergeNonEmpty, chooseMergeNow,
    mergeNowAccepted, mergeNowBlocked, fixBlocked,
    pushRemote, retryRemoteCheck, driftWhileWaiting, pushUpdate,
    remoteFoundMerged, remoteFoundMergedOwnershipBlocked, remoteFoundNotMerged,
    confirmForceRemove,
    intentDiscard, declineDiscard, confirmDiscard, confirmDiscardOwnershipBlocked,
    landOnDefault,
    buggyExitOnBlocked, buggyRemoveWithoutMerge, buggyMergeWithoutPush, buggyMergeWhileDiverged, buggyLandWithoutExit,
    done,
  }

  /// R1: a worktree is removed only if merged, empty or discarded by a typed confirm.
  val removedImpliesPreserved = removed implies (merged or not(hasCommits) or discardConfirmed)
  /// R2: a merge follows a push.
  val remoteRemovalRequiresPush = merged implies pushed
  /// R2: a merge is never checked against a drifted tip.
  val mergedRequiresInSync = merged implies inSync
  /// R4: the primary checkout lands on the default branch only after ExitWorktree.
  val onDefaultRequiresExited = onDefault implies (kept or removed)
  /// R3: a blocked merge never leaves the worktree.
  val blockedStaysInWorktree = (phase == "merge_blocked") implies not(kept or removed)
}
