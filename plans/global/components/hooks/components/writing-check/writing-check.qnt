// One run of writing-check.py: a hook call (post, stop) or a command (file, report).
//
// The inputs are picked once, at the start: the command, the mode, which
// optional files exist, and what the check of the text finds. The public
// release has no .claude/CLAUDE.md, no chart catalog, no STE data and often no
// mode file, so each of those can be missing.
//
// Not modelled: how each rule scores a sentence (the unit tests of the script
// check each rule), the thresholds, the log line, and the release list itself
// (R17 and R20 are checked by the release scans and the e2e test).
// 1-design.md explains each state, its invariants and its expected output.

module writingCheck {
  // post: a .md edit. stop: the last reply. file: check one file. report: the pane.
  val COMMANDS = Set("post", "stop", "file", "report")
  // "none": no mode file, which reads as pro.
  val MODES = Set("none", "off", "casual", "pro")

  var cmd: str
  var mode: str
  // .claude/hooks/writing-rules.md is there and holds its four tables.
  var rulesOk: bool
  // .claude/CLAUDE.md with its Terms table is there.
  var hasTerms: bool
  var hasSte: bool
  var hasCatalog: bool
  // The edited path is raw research, or the file has the off mark.
  var skipPath: bool
  // A rule other than fullPaths fails.
  var ruleFails: bool
  // A short path in the reply fails fullPaths.
  var pathFails: bool
  // The added text holds a chart signal: a table, a prose signal or a data mention.
  var hasTable: bool
  // A stop that already blocked once (stop_hook_active).
  var stopActive: bool

  // "received", "loaded", "checked", "quiet", "fed_back", "reported", "failed_open", "failed"
  var phase: str
  var exitCode: int
  // stdout holds a block JSON for Claude.
  var blocked: bool
  // The message names the rules file.
  var namesRules: bool
  var termRulesRun: bool
  var steRun: bool
  var chartNote: bool
  // An error line on stderr.
  var errLine: bool

  def isHook: bool = cmd == "post" or cmd == "stop"
  def effMode: str = if (mode == "none") "pro" else mode
  // fullPaths is checked in replies only (R12).
  def failsAny: bool = ruleFails or (cmd == "stop" and pathFails)
  def skips: bool = isHook and (effMode == "off" or (cmd == "post" and skipPath) or (cmd == "stop" and stopActive))

  action init = {
    nondet c = COMMANDS.oneOf()
    nondet m = MODES.oneOf()
    nondet r = Set(true, false).oneOf()
    nondet t = Set(true, false).oneOf()
    nondet s = Set(true, false).oneOf()
    nondet k = Set(true, false).oneOf()
    nondet sp = Set(true, false).oneOf()
    nondet rf = Set(true, false).oneOf()
    nondet pf = Set(true, false).oneOf()
    nondet tb = Set(true, false).oneOf()
    nondet sa = Set(true, false).oneOf()
    all {
      cmd' = c, mode' = m, rulesOk' = r, hasTerms' = t, hasSte' = s, hasCatalog' = k,
      skipPath' = sp, ruleFails' = rf, pathFails' = pf, hasTable' = tb, stopActive' = sa,
      phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
      termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
    }
  }

  action keepInputs = all {
    cmd' = cmd, mode' = mode, rulesOk' = rulesOk, hasTerms' = hasTerms, hasSte' = hasSte,
    hasCatalog' = hasCatalog, skipPath' = skipPath, ruleFails' = ruleFails,
    pathFails' = pathFails, hasTable' = hasTable, stopActive' = stopActive,
  }

  action keepOut = all {
    exitCode' = exitCode, blocked' = blocked, namesRules' = namesRules,
    termRulesRun' = termRulesRun, steRun' = steRun, chartNote' = chartNote, errLine' = errLine,
  }

  /// R9: move mode off. R10: move skip path. R3: a stop blocks once at most.
  // A hook in mode off, a post on a path it skips or on a non-.md file, or a
  // stop that already blocked once, exits with nothing. The script decides this
  // before it reads the rules file.
  action skip = all {
    phase == "received", skips, keepInputs,
    phase' = "quiet", exitCode' = 0, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }

  /// R18: move load. R19: the optional files may be missing.
  // The script reads the word tables of the rules file, and the Terms table if
  // .claude/CLAUDE.md is there. The STE data is read only if it is there.
  action load = all {
    phase == "received", rulesOk, not(skips),
    keepInputs, phase' = "loaded",
    exitCode' = exitCode, blocked' = blocked, namesRules' = namesRules,
    termRulesRun' = hasTerms, steRun' = hasSte, chartNote' = chartNote, errLine' = errLine,
  }

  /// R3: move fail open.
  // A broken rules file: a hook prints one error line and exits 0.
  action failOpen = all {
    phase == "received", isHook, not(rulesOk), not(skips),
    keepInputs, phase' = "failed_open", exitCode' = 0, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = true,
  }

  /// R19: move fail. A command with a broken rules file says so and exits 1.
  action failCmd = all {
    phase == "received", not(isHook), not(rulesOk), keepInputs,
    phase' = "failed", exitCode' = 1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = true,
  }

  /// R11: move report.
  action report = all {
    phase == "loaded", cmd == "report", keepInputs, phase' = "reported", exitCode' = 0,
    blocked' = blocked, namesRules' = namesRules, termRulesRun' = termRulesRun,
    steRun' = steRun, chartNote' = chartNote, errLine' = errLine,
  }

  /// R4: move check. R13: a chart note only with the catalog.
  action check = all {
    phase == "loaded", cmd != "report", keepInputs, phase' = "checked",
    exitCode' = exitCode, blocked' = blocked, namesRules' = namesRules,
    termRulesRun' = termRulesRun, steRun' = steRun,
    chartNote' = (cmd == "post" and hasTable and hasCatalog), errLine' = errLine,
  }

  /// R1: a reply is logged only. R2: a .md edit gets feedback. R12: a short path blocks the stop once.
  action feedBack = all {
    phase == "checked", keepInputs, phase' = "fed_back",
    termRulesRun' = termRulesRun, steRun' = steRun, chartNote' = chartNote, errLine' = errLine,
    // A chart note alone is advice: it goes as added context, not as a block.
    val shows = if (cmd == "post") ruleFails
                else if (cmd == "stop") pathFails
                else false
    all {
      blocked' = shows,
      namesRules' = (shows or (cmd == "file" and failsAny)),
      exitCode' = if (cmd == "file" and failsAny) 1 else 0,
    },
  }

  /// R3: a finished run stays as it is.
  action done = all { phase.in(Set("quiet", "fed_back", "reported", "failed_open", "failed")), keepInputs, keepOut, phase' = phase }

  action step = any { skip, load, failOpen, failCmd, report, check, feedBack, done }

  val finished = phase.in(Set("quiet", "fed_back", "reported", "failed_open", "failed"))

  /// R3: a hook never fails the session: it exits 0, whatever it finds.
  val hookExitsZero = (finished and isHook) implies exitCode == 0
  /// R1: a reply blocks only for a short path (R12).
  val replyBlocksOnlyForPaths = (finished and cmd == "stop" and blocked) implies pathFails
  /// R2: a failing .md edit gets feedback, unless skipped or off.
  val editFeedback = (phase == "fed_back" and cmd == "post" and ruleFails) implies blocked
  /// R18: each block message names the file of each rule that failed.
  val messageNamesRules = blocked implies namesRules
  /// R19: no Terms file: the term rules do not run, and nothing fails for it.
  val termsOptional = (finished and not(hasTerms)) implies (not(termRulesRun) and not(errLine and rulesOk))
  /// R19: no STE data: steWords does not run.
  val steOptional = not(hasSte) implies not(steRun)
  /// R13 R19: no catalog, no chart note.
  val catalogOptional = not(hasCatalog) implies not(chartNote)
  /// R11 R19: report works with only the rules file.
  val reportNeedsOnlyRules = (finished and cmd == "report" and rulesOk) implies (phase == "reported" and exitCode == 0 and not(errLine))
  /// R9: no mode file reads as pro: the hook checks.
  val noModeIsPro = (finished and isHook and mode == "none" and rulesOk and not(skips)) implies phase == "fed_back"
  /// R9: mode off checks nothing.
  val offIsQuiet = (finished and isHook and mode == "off") implies (phase == "quiet" and not(blocked))
  /// R10: a skipped path gets no feedback.
  val skipIsQuiet = (finished and cmd == "post" and skipPath) implies not(blocked)

  /// R3: a stop that already blocked once does not block again.
  val stopBlocksOnce = (finished and cmd == "stop" and stopActive) implies not(blocked)
  /// R13: a chart note alone never blocks.
  val noteIsAdvice = (finished and cmd == "post" and not(ruleFails)) implies not(blocked)
  /// R12: a short path never fails a file check.
  val fileIgnoresPaths = (finished and cmd == "file" and not(ruleFails) and rulesOk) implies exitCode == 0

  val allInvariants = and {
    stopBlocksOnce, noteIsAdvice, fileIgnoresPaths,
    hookExitsZero, replyBlocksOnlyForPaths, editFeedback, messageNamesRules, termsOptional,
    steOptional, catalogOptional, reportNeedsOnlyRules, noModeIsPro, offIsQuiet, skipIsQuiet,
  }

  // NEGATIVE CONTROL: must fail. Some edit gets feedback.
  val negativeControl = not(phase == "fed_back" and blocked)

  /// R19: the start of a run in the public clone.
  // A run in the public clone: only the rules file, no terms, STE, catalog or mode file.
  action initPublic(c: str, rf: bool, pf: bool, tb: bool): bool = all {
    cmd' = c, mode' = "none", rulesOk' = true, hasTerms' = false, hasSte' = false, hasCatalog' = false,
    skipPath' = false, ruleFails' = rf, pathFails' = pf, hasTable' = tb, stopActive' = false,
    phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }

  /// R19: the config pane in the public clone.
  /// reported
  run publicReportTest = initPublic("report", false, false, false).then(load).then(report)
    .then(all { assert(phase == "reported"), assert(exitCode == 0), assert(not(errLine)), assert(not(termRulesRun)), done })

  /// R2: a failing edit in the public clone gets feedback, with no chart note.
  /// fed_back
  run publicEditTest = initPublic("post", true, false, true).then(load).then(check).then(feedBack)
    .then(all { assert(blocked), assert(namesRules), assert(not(chartNote)), assert(exitCode == 0), done })

  /// R12: a short path in a reply blocks once.
  run publicReplyPathTest = initPublic("stop", false, true, false).then(load).then(check).then(feedBack)
    .then(all { assert(blocked), assert(exitCode == 0), done })

  /// R1: a reply that fails another rule is only logged.
  run replyLoggedTest = initPublic("stop", true, false, false).then(load).then(check).then(feedBack)
    .then(all { assert(not(blocked)), assert(exitCode == 0), done })

  /// R3: a broken rules file fails open in a hook.
  /// failed_open
  run brokenRulesHookTest = all {
    cmd' = "post", mode' = "pro", rulesOk' = false, hasTerms' = true, hasSte' = true, hasCatalog' = true,
    skipPath' = false, ruleFails' = true, pathFails' = false, hasTable' = false, stopActive' = false,
    phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }.then(failOpen).then(all { assert(exitCode == 0), assert(errLine), assert(not(blocked)), done })

  /// R13: in the private harness a docs table gets a chart note, as advice.
  run privateChartTest = all {
    cmd' = "post", mode' = "pro", rulesOk' = true, hasTerms' = true, hasSte' = true, hasCatalog' = true,
    skipPath' = false, ruleFails' = false, pathFails' = false, hasTable' = true, stopActive' = false,
    phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }.then(load).then(check).then(feedBack)
    .then(all { assert(chartNote), assert(not(blocked)), assert(termRulesRun), assert(steRun), done })

  /// R9: a hook in mode off prints nothing.
  /// quiet
  run offQuietTest = all {
    cmd' = "stop", mode' = "off", rulesOk' = true, hasTerms' = false, hasSte' = false, hasCatalog' = false,
    skipPath' = false, ruleFails' = true, pathFails' = true, hasTable' = false, stopActive' = false,
    phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }.then(skip).then(all { assert(phase == "quiet"), assert(exitCode == 0), assert(not(blocked)), done })

  /// R19: the report with no rules file says so and exits 1.
  /// failed
  run reportNoRulesTest = all {
    cmd' = "report", mode' = "none", rulesOk' = false, hasTerms' = false, hasSte' = false, hasCatalog' = false,
    skipPath' = false, ruleFails' = false, pathFails' = false, hasTable' = false, stopActive' = false,
    phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }.then(failCmd).then(all { assert(phase == "failed"), assert(exitCode == 1), assert(errLine), done })

  /// R3: a stop that already blocked once is quiet.
  run stopOnceTest = all {
    cmd' = "stop", mode' = "pro", rulesOk' = true, hasTerms' = true, hasSte' = false, hasCatalog' = false,
    skipPath' = false, ruleFails' = false, pathFails' = true, hasTable' = false, stopActive' = true,
    phase' = "received", exitCode' = -1, blocked' = false, namesRules' = false,
    termRulesRun' = false, steRun' = false, chartNote' = false, errLine' = false,
  }.then(skip).then(all { assert(phase == "quiet"), assert(not(blocked)), done })
}
