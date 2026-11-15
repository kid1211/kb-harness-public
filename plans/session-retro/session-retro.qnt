// One retro run, from the user's yes at the end of worktree-end to a committed page, and the reminder at
// the next session start.
//
// The page itself, its findings and their statuses are in
// components/findings-page/findings-page.qnt. Here a page is one step: written or not.
// Not imported: that model's vars would have to move in every action here, and no
// invariant here reads them.
//
// Not modelled, held by the Bash tests: that the run adds no turn after the question and leaves the
// transcript as it was, and that the commit holds the page alone.
module sessionRetro {
  pure val MAX_DAYS = 10
  pure val AGES = Set(0, 5, 30, 61, 120)   // minutes since the last transcript entry

  var phase: str              // "idle", "running", "cold", "forked", "written", "committed", "failed"
  var saidYes: bool           // the user said yes to the last question
  var age: int                // minutes since the last transcript entry, at the start of the run
  var readTranscript: bool    // this run read the transcript
  var unpushed: bool          // a commit of the page is not pushed yet
  var failLog: int            // lines in the failure log
  var daysSince: int          // days since the reminder last showed the count. 7 at first: no reminder has shown yet
  var shown: bool             // the reminder showed at the last session start
  var fails: int              // failures so far, a failed run or a failed push
  var reported: int           // failures the reminder showed

  action init = all {
    phase' = "idle", saidYes' = false, age' = 0, readTranscript' = false,
    unpushed' = false, failLog' = 0, daysSince' = 7, shown' = false, fails' = 0, reported' = 0,
  }

  /// R1: after each ExitWorktree, worktree-end asks the user. Only a yes starts a run.
  action askWith(yes: bool, a: int): bool = all {
      Set("idle", "committed", "failed").contains(phase),
      saidYes' = yes, age' = if (yes) a else age,
      phase' = if (yes) "running" else phase,
      readTranscript' = if (yes) false else readTranscript,
      unpushed' = unpushed, failLog' = failLog, daysSince' = daysSince, shown' = shown, fails' = fails, reported' = reported,
  }

  /// R1: The user says yes or no, and the transcript has any age.
  action ask = {
    nondet yes = Set(true, false).oneOf()
    nondet a = AGES.oneOf()
    askWith(yes, a)
  }

  /// R14: the run picks cold or fork by the age of the last entry.
  action decide = all {
    phase == "running",
    phase' = if (age > 60) "cold" else "forked",
    saidYes' = saidYes, age' = age, readTranscript' = readTranscript,
    unpushed' = unpushed, failLog' = failLog, daysSince' = daysSince, shown' = shown, fails' = fails, reported' = reported,
  }

  /// R14: the fork reads the transcript, on the session's own model.
  action read = all {
    phase == "forked", not(readTranscript),
    readTranscript' = true,
    phase' = phase, saidYes' = saidYes, age' = age,
    unpushed' = unpushed, failLog' = failLog, daysSince' = daysSince, shown' = shown, fails' = fails, reported' = reported,
  }

  /// R11: the script writes the page from the findings, or the one-line cold page.
  action writePage = all {
    (phase == "cold") or ((phase == "forked") and readTranscript),
    phase' = "written",
    saidYes' = saidYes, age' = age, readTranscript' = readTranscript,
    unpushed' = unpushed, failLog' = failLog, daysSince' = daysSince, shown' = shown, fails' = fails, reported' = reported,
  }

  /// R16: the script commits the page and pushes it. A failed push leaves it committed and logged.
  action commit = {
    nondet pushOk = Set(true, false).oneOf()
    all {
      phase == "written",
      phase' = "committed",
      unpushed' = not(pushOk),
      failLog' = if (pushOk) failLog else failLog + 1,
      fails' = if (pushOk) fails else fails + 1, reported' = reported,
      saidYes' = saidYes, age' = age, readTranscript' = readTranscript, daysSince' = daysSince, shown' = shown,
    }
  }

  /// R1: a step fails: the fork, a secret on the page, the lock, a git step. The run logs why.
  action runFails = all {
    Set("running", "cold", "forked", "written").contains(phase),
    phase' = "failed", failLog' = failLog + 1, fails' = fails + 1, reported' = reported,
    saidYes' = saidYes, age' = age, readTranscript' = readTranscript,
    unpushed' = unpushed, daysSince' = daysSince, shown' = shown,
  }

  /// R10: a day passes.
  action dayPasses = all {
    daysSince < MAX_DAYS,
    daysSince' = daysSince + 1,
    phase' = phase, saidYes' = saidYes, age' = age, readTranscript' = readTranscript,
    unpushed' = unpushed, failLog' = failLog, shown' = shown, fails' = fails, reported' = reported,
  }

  /// R10: at a new session start, the reminder shows the failure log, and the count once 7 days have passed.
  action sessionStart = {
    val due = daysSince >= 7
    all {
      shown' = (due or (failLog > 0)),
      daysSince' = if (due) 0 else daysSince,
      failLog' = 0, reported' = reported + failLog, fails' = fails,
      phase' = phase, saidYes' = saidYes, age' = age, readTranscript' = readTranscript, unpushed' = unpushed,
    }
  }

  action step = any { ask, decide, read, writePage, commit, runFails, dayPasses, sessionStart }

  /// R1: a run starts only from a yes. A session on main is never asked.
  val noRunWithoutYes = phase == "running" implies saidYes
  /// R14: a run reads the transcript only when its last entry is an hour old or less.
  val readOnlyWhenFresh = readTranscript implies age <= 60
  /// R14: a cold page comes from a run that read nothing.
  val coldNoRead = phase == "cold" implies not(readTranscript)
  /// R1: each failure, of a run or of a push, is in the log until the reminder shows it.
  val failuresKept = fails == failLog + reported
  /// NEGATIVE CONTROL: false on purpose. A run that fails reaches the failed phase.
  val neverFails = phase != "failed"

  /// R1: a yes starts a run on a transcript of age a.
  action startRun(a: int): bool = askWith(true, a)

  /// R14: an old transcript gives a cold page, read by no one.
  run coldRunTest = init.then(startRun(120)).then(decide).then(writePage)
    .expect(phase == "written" and not(readTranscript))
  /// R14: a fresh transcript is read by the fork.
  run fullRunTest = init.then(startRun(5)).then(decide).then(read).then(writePage)
    .expect(phase == "written" and readTranscript)
  /// R1: a failure is shown at the next session start.
  /// failed
  run failShownTest = init.then(startRun(5)).then(decide).then(runFails).then(sessionStart)
    .expect(shown and failLog == 0)
  /// R16: a written page is committed.
  /// committed
  run committedTest = init.then(startRun(5)).then(decide).then(read).then(writePage).then(commit)
    .expect(phase == "committed")
  /// R10: the count shows on the first session start 7 days after the last.
  run weeklyTest = init.then(sessionStart).then(7.reps(_ => dayPasses)).then(sessionStart).expect(shown and daysSince == 0)
  /// R10: the first session start shows the count: no reminder has shown yet.
  run firstReminderTest = init.then(sessionStart).expect(shown and daysSince == 0)
  /// R10: the count does not show at 6 days.
  run notBeforeSevenTest = init.then(sessionStart).then(6.reps(_ => dayPasses)).then(sessionStart).expect(not(shown) and daysSince == 6)
  /// R1: a run again after a commit starts a new run.
  run againAfterCommitTest = init.then(startRun(5)).then(decide).then(read).then(writePage).then(commit)
    .then(startRun(5)).expect(phase == "running")
  /// R14: a fork cannot read an old transcript.
  run noReadWhenOldTest = init.then(startRun(61)).then(decide).then(read).fail()
  /// R1: a no starts no run.
  run noStartsNothingTest = init.then(askWith(false, 5)).expect(phase == "idle")
  /// R1: a run cannot start while another is running.
  run noStartWhileRunningTest = init.then(startRun(5)).then(startRun(5)).fail()
}
