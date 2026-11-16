// The two op skills: one run of op-fork-keep or op-fork-new-wt. States are the state nodes
// of architecture.md. The decisions facts?, cmux? and fork? sit inside the actions. A run
// ends in forked, or fails with nothing left open.
//
// Not modelled, held by the tests: the name of the new worktree (-2, -3), the cd in the pane,
// and the text of each line.
module opSkills {
  pure val KINDS = Set("keep", "newwt")

  var phase: str     // "start", "forking", "forked", "fact_missing", "not_in_cmux", "command_failed"
  var kind: str      // the skill the user ran
  var panes: int     // panes this run opened and left open
  var worktrees: int // new worktrees this run left

  /// R24: a run starts with no pane or worktree, for the skill the user ran.
  action initWith(k: str): bool = all {
    KINDS.contains(k),
    phase' = "start", kind' = k, panes' = 0, worktrees' = 0,
  }
  action init = {
    nondet k = KINDS.oneOf()
    initWith(k)
  }

  /// R24: a missing fact stops the run before anything opens.
  action factMissing: bool = all {
    phase == "start",
    phase' = "fact_missing",
    kind' = kind, panes' = panes, worktrees' = worktrees,
  }
  /// R11: a fork skill outside cmux opens nothing.
  action notInCmux: bool = all {
    phase == "start",
    phase' = "not_in_cmux",
    kind' = kind, panes' = panes, worktrees' = worktrees,
  }
  /// R11: a fork skill inside cmux sends the fork command to a new pane.
  action startFork: bool = all {
    phase == "start",
    phase' = "forking",
    kind' = kind, panes' = panes, worktrees' = worktrees,
  }
  /// R7, R23: the fork runs in a new pane. Only op-fork-new-wt makes a worktree.
  action forkOk: bool = all {
    phase == "forking",
    phase' = "forked",
    panes' = 1, worktrees' = if (kind == "newwt") 1 else 0,
    kind' = kind,
  }
  /// R11: a failed command closes the pane the run opened and removes its worktree.
  action commandFailed: bool = all {
    phase == "forking",
    phase' = "command_failed",
    panes' = 0, worktrees' = 0,
    kind' = kind,
  }
  /// R25: a finished run stays where it ended.
  action done: bool = all {
    phase != "start" and phase != "forking",
    phase' = phase, kind' = kind, panes' = panes, worktrees' = worktrees,
  }

  action step = any { factMissing, notInCmux, startFork, forkOk, commandFailed, done }

  /// R11, R24: a run that fails leaves no pane or worktree.
  val failLeavesNothing = (phase == "fact_missing" or phase == "not_in_cmux" or phase == "command_failed")
    implies (panes == 0 and worktrees == 0)
  /// R11, R7: a fork gives exactly one new pane.
  val onePane = phase == "forked" implies panes == 1
  /// R7, R23: only op-fork-new-wt leaves a new worktree.
  val worktreeOnlyNewWt = worktrees == (if (phase == "forked" and kind == "newwt") 1 else 0)

  /// NEGATIVE CONTROL: false on purpose. Some run ends in a fork.
  val neverForked = phase != "forked"

  /// forked
  /// R7: op-fork-keep forks in a pane and makes no worktree.
  run keepTest = initWith("keep").then(startFork).then(forkOk)
    .expect(phase == "forked" and panes == 1 and worktrees == 0)
  /// R23: op-fork-new-wt forks in a pane and a new worktree.
  run newWtTest = initWith("newwt").then(startFork).then(forkOk)
    .expect(phase == "forked" and panes == 1 and worktrees == 1)

  /// fact_missing
  /// R24: a missing fact opens nothing.
  run factTest = initWith("keep").then(factMissing)
    .expect(phase == "fact_missing" and panes == 0)

  /// not_in_cmux
  /// R11: outside cmux nothing opens.
  run noCmuxTest = initWith("newwt").then(notInCmux)
    .expect(phase == "not_in_cmux" and panes == 0 and worktrees == 0)

  /// command_failed
  /// R11: a failed fork command closes the pane.
  run failTest = initWith("newwt").then(startFork).then(commandFailed)
    .expect(phase == "command_failed" and panes == 0 and worktrees == 0)
}
