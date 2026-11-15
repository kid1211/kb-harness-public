// worktree-sync's guard order, as a Quint model.
//
// Under this repo's spec-quint gate, worktree-sync's three guards (in a linked
// worktree? clean tree? did the fetch succeed?) plus the post-rebase check
// (conflict?) are predicates over git state at rest, not a transition — so this
// is a CONFIGURATION model: `init` ranges nondeterministically over every
// combination of the four booleans, `step` is inert, and the invariants pin down
// which single outcome each combination must produce.
//
// What this does NOT cover: the two hard prohibitions (never touch the local
// `main` ref, never auto-stash/auto-abort/force) are predicates over the
// script's own source — a single file — so per the gate they skip the model
// entirely and get a shell check directly against scripts/sync.sh.
//
// The state space is the input to worktree-sync's guard chain:
//
//   isWorktree   git-dir != git-common-dir, submodule false-positive excluded
//   isClean      git status --porcelain is empty
//   fetchOk      git fetch origin main succeeded
//   conflict     the rebase left a rebase-merge/rebase-apply directory behind
//
// and `outcome` is the one of five stop points the guard chain reaches, in
// precedence order: NOT_WORKTREE beats DIRTY beats FETCH_FAILED beats CONFLICT
// beats SUCCESS.

module syncWorktreeOutcome {
  pure val NOT_WORKTREE = 0
  pure val DIRTY = 1
  pure val FETCH_FAILED = 2
  pure val CONFLICT = 3
  pure val SUCCESS = 4

  var isWorktree: int
  var isClean: int
  var fetchOk: int
  var conflict: int
  var outcome: int

  pure def classify(worktree: int, clean: int, fetch: int, confl: int): int =
    if (worktree == 0) NOT_WORKTREE
    else if (clean == 0) DIRTY
    else if (fetch == 0) FETCH_FAILED
    else if (confl == 1) CONFLICT
    else SUCCESS

  // Every combination of the four booleans, including ones a mis-ordered guard
  // chain would misclassify — that's what the invariants below catch.
  action init = {
    nondet w = oneOf(0.to(1))
    nondet c = oneOf(0.to(1))
    nondet f = oneOf(0.to(1))
    nondet x = oneOf(0.to(1))
    all {
      isWorktree' = w,
      isClean' = c,
      fetchOk' = f,
      conflict' = x,
      outcome' = classify(w, c, f, x),
    }
  }

  // Inert; never fires at --max-steps=0, but `verify` needs the name to exist.
  action step = all {
    isWorktree' = isWorktree,
    isClean' = isClean,
    fetchOk' = fetchOk,
    conflict' = conflict,
    outcome' = outcome,
  }

  // Outside a worktree, nothing else matters — worktree-sync no-ops.
  val notWorktreeWins = (isWorktree == 0).implies(outcome == NOT_WORKTREE)

  // Each stop point fires only inside the state it names, in guard order.
  val dirtyOnlyInsideWorktree =
    (outcome == DIRTY).implies(isWorktree == 1 and isClean == 0)
  val fetchFailedOnlyWhenCleanWorktree =
    (outcome == FETCH_FAILED).implies(isWorktree == 1 and isClean == 1 and fetchOk == 0)
  val conflictOnlyAfterFetchOk =
    (outcome == CONFLICT).implies(isWorktree == 1 and isClean == 1 and fetchOk == 1 and conflict == 1)
  val successOnlyWhenAllClear =
    (outcome == SUCCESS).implies(isWorktree == 1 and isClean == 1 and fetchOk == 1 and conflict == 0)

  // The reverse direction: an all-clear worktree always reaches SUCCESS, not
  // just "some outcome consistent with it."
  val allClearAlwaysSucceeds =
    (isWorktree == 1 and isClean == 1 and fetchOk == 1 and conflict == 0).implies(outcome == SUCCESS)

  // NEGATIVE CONTROL — deliberately false: SUCCESS is reachable (isWorktree=1,
  // isClean=1, fetchOk=1, conflict=0), so "outcome is never SUCCESS" must fail.
  // Its counterexample also doubles as spec-implement's SUCCESS fixture.
  val neverSucceeds = outcome != SUCCESS

  // Witnesses, not requirements: each is deliberately false so `quint verify`
  // returns a counterexample landing in that one outcome bucket. spec-implement
  // materialises those counterexamples as fixtures — this is the model's own
  // exploration choosing the state, not a directory someone typed by hand.
  val witnessNotWorktree = outcome != NOT_WORKTREE
  val witnessDirty = outcome != DIRTY
  val witnessFetchFailed = outcome != FETCH_FAILED
  val witnessConflict = outcome != CONFLICT

  run notWorktreeWinsTest = init.expect(notWorktreeWins)
  run dirtyOnlyInsideWorktreeTest = init.expect(dirtyOnlyInsideWorktree)
  run fetchFailedOnlyWhenCleanWorktreeTest = init.expect(fetchFailedOnlyWhenCleanWorktree)
  run conflictOnlyAfterFetchOkTest = init.expect(conflictOnlyAfterFetchOk)
  run successOnlyWhenAllClearTest = init.expect(successOnlyWhenAllClear)
  run allClearAlwaysSucceedsTest = init.expect(allClearAlwaysSucceeds)
}
