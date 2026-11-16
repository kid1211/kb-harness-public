// knowledge-base-architecture: the three areas of a KB topic folder, and one
// write by Claude into it.
//
// Module kbWrite is one write by Claude to one KB file, a transition model:
// the hooks classify the file by its name, check a source file's event date,
// leave staging free, and make the user approve a write to a consolidated page.
// The PreToolUse hook sees Write and Edit only. A write through Bash skips it,
// and the PostToolUse hook flags it after the fact.
// What Claude finds in the file (its area, a date, a conflict, the user's answer)
// is chosen at init or by nondet, so every mix is explored.
//
// Module kbPage is the check of a page at rest, a configuration model: the
// area a name gives, and the confidence score a heading takes from its parents.
//
// Not modelled: whether Claude sees a conflict (an agent judges it), what a
// page says, the topic recheck by a fresh agent, and the one-time move of
// today's files (the migrate component).

module kbWrite {
  var phase: str
  // Found by the hooks.
  var area: str          // "source", "staging", "consolidated" or "exempt"
  var viaBash: bool      // Claude writes through Bash, which the PreToolUse hook does not see
  var isNew: bool        // the file does not exist yet
  var hasDate: bool      // an ISO date, YYYY-MM, YYYY or undated- in its name or its folder's name
  var scoreAtRoot: bool  // the page as it will be has the user's score in its frontmatter or under its title
  var citesSource: bool  // each fact of the page as it will be links to a source file that exists
  // What happens.
  var userYes: bool
  var conflict: bool
  var wrote: bool
  var todoP1: bool       // a TODO(P1) marker in staging names the conflict
  var userTold: bool
  var flagged: bool      // the PostToolUse hook named a change that skipped the PreToolUse hook
  var consolidatedChanged: bool
  var sourceChanged: bool

  /// R9: a write starts. The hooks find the area, the date, the score and the sources.
  action start(a: str, b: bool, n: bool, d: bool, s: bool, c: bool): bool = all {
    phase' = "start", area' = a, viaBash' = b, isNew' = n, hasDate' = d, scoreAtRoot' = s, citesSource' = c,
    userYes' = false, conflict' = false, wrote' = false, todoP1' = false, userTold' = false, flagged' = false,
    consolidatedChanged' = false, sourceChanged' = false,
  }
  action init = {
    nondet a = Set("source", "staging", "consolidated", "exempt").oneOf()
    nondet b = Set(true, false).oneOf()
    nondet n = Set(true, false).oneOf()
    nondet d = Set(true, false).oneOf()
    nondet s = Set(true, false).oneOf()
    nondet c = Set(true, false).oneOf()
    start(a, b, n, d, s, c)
  }

  action keepFacts = all {
    area' = area, viaBash' = viaBash, isNew' = isNew, hasDate' = hasDate, scoreAtRoot' = scoreAtRoot, citesSource' = citesSource,
  }

  /// R9, R24: the name gives the area. A file outside the KB pages, such as CLAUDE.md or plans/, is exempt.
  action classify = all {
    phase == "start",
    not(viaBash),
    phase' = if (area == "exempt") "written"
             else if (area == "consolidated") "asking"
             else if (area == "source") "dating"
             else "free",
    keepFacts,
    userYes' = userYes, conflict' = conflict, todoP1' = todoP1, userTold' = userTold, flagged' = flagged,
    wrote' = (area == "exempt"), consolidatedChanged' = false, sourceChanged' = false,
  }

  /// R25: a write through Bash skips the PreToolUse hook. The PostToolUse hook names each KB file it changed, and Claude tells the user.
  action bashWrite = all {
    phase == "start",
    viaBash,
    val kb = area != "exempt"
    all {
      phase' = if (kb) "flagged" else "written",
      keepFacts,
      userYes' = userYes, conflict' = conflict, todoP1' = todoP1,
      userTold' = kb, flagged' = kb,
      wrote' = true, consolidatedChanged' = (area == "consolidated"), sourceChanged' = (area == "source"),
    },
  }

  /// R21: a source file needs an event date, and source stays as it came in. An existing source file is changed only with the user's yes.
  action sourceWith(yes: bool): bool = all {
    phase == "dating",
    val ok = hasDate and (isNew or yes)
    all {
      phase' = if (ok) "written" else "refused",
      keepFacts,
      userYes' = yes, conflict' = conflict, todoP1' = todoP1, userTold' = userTold, flagged' = flagged,
      wrote' = ok, sourceChanged' = ok, consolidatedChanged' = false,
    },
  }
  /// R21: a source write, with the user's yes or not.
  action source = { nondet y = Set(true, false).oneOf() sourceWith(y) }

  /// R12: staging is Claude's area. A write needs no approval.
  action writeStaging = all {
    phase == "free",
    phase' = "comparing",
    keepFacts,
    userYes' = userYes, conflict' = conflict, todoP1' = todoP1, userTold' = userTold, flagged' = flagged,
    wrote' = true, consolidatedChanged' = false, sourceChanged' = false,
  }

  /// R7, R23: after a staging write, Claude compares it with the consolidated page of the topic. A conflict becomes a TODO(P1) marker in staging, and Claude tells the user and proposes a fork session. The page does not change.
  action compareWith(c: bool): bool = all {
    phase == "comparing",
    phase' = if (c) "raised" else "written",
    keepFacts,
    userYes' = userYes, conflict' = c, todoP1' = c, userTold' = c, flagged' = flagged,
    wrote' = wrote, consolidatedChanged' = false, sourceChanged' = false,
  }
  /// R7: a staging write is compared with the consolidated page, with a conflict or not.
  action compare = { nondet c = Set(true, false).oneOf() compareWith(c) }

  /// R7, R22, R4: the hook checks the page as it will be before it asks the user. With no root score or a fact with no source, it refuses and the user is not asked. Else the user says yes or no.
  action askJoeWith(yes: bool): bool = all {
    phase == "asking",
    val complete = scoreAtRoot and citesSource
    val ok = complete and yes
    all {
      phase' = if (ok) "written" else "refused",
      keepFacts,
      userYes' = ok, conflict' = conflict, todoP1' = todoP1, userTold' = complete, flagged' = flagged,
      wrote' = ok, consolidatedChanged' = ok, sourceChanged' = false,
    },
  }
  /// R22: a consolidated write, with the user's yes or not.
  action askJoe = { nondet y = Set(true, false).oneOf() askJoeWith(y) }

  // A finished write stays where it is (trap 1).
  /// R9: a finished write stays as it is.
  action done = all {
    Set("written", "refused", "raised", "flagged").contains(phase),
    phase' = phase, keepFacts,
    userYes' = userYes, conflict' = conflict, todoP1' = todoP1, userTold' = userTold, flagged' = flagged,
    wrote' = wrote, consolidatedChanged' = consolidatedChanged, sourceChanged' = sourceChanged,
  }

  action step = any { classify, bashWrite, source, writeStaging, compare, askJoe, done }

  /// R7, R22: through the hook, Claude never changes a consolidated page without the user's yes.
  val consolidatedOnlyWithYes = (consolidatedChanged and not(viaBash)) implies userYes
  /// R22, R4: through the hook, a consolidated page that changed has the user's score at its root and cites its source.
  val consolidatedComplete = (consolidatedChanged and not(viaBash)) implies (scoreAtRoot and citesSource)
  /// R22, R4: the user is asked only about a page that has its score and its sources.
  val askOnlyComplete = (area == "consolidated" and userTold and not(viaBash)) implies (scoreAtRoot and citesSource)
  /// R25: a KB file changed through Bash is flagged, and the user is told.
  val bashFlagged = (viaBash and wrote and area != "exempt") implies (flagged and userTold)
  /// R7, R23: a conflict ends with a TODO(P1) marker and the user told, and the consolidated page as it was.
  val conflictReachesJoe = conflict implies (todoP1 and userTold and not(consolidatedChanged))
  /// R21: through the hook, a source file written has an event date.
  val sourceHasDate = (sourceChanged and not(viaBash)) implies hasDate
  /// R21: through the hook, an existing source file changes only with the user's yes.
  val sourceKeptAsItCame = (sourceChanged and not(viaBash)) implies (isNew or userYes)
  /// R12: a staging write never needs the user.
  val stagingFree = (area == "staging" and phase == "written") implies wrote
  /// R7, R22, R25: no consolidated page changes unseen by the user: they said yes, or they was told after.
  val noSilentChange = consolidatedChanged implies (userYes or (flagged and userTold))

  val safety = consolidatedOnlyWithYes and consolidatedComplete and askOnlyComplete and bashFlagged
    and conflictReachesJoe and sourceHasDate and sourceKeptAsItCame and stagingFree and noSilentChange

  // NEGATIVE CONTROL: false on purpose. Claude does write files.
  val neverWrites = not(wrote)

  /// R7: a conflict in staging reaches the user and leaves the page alone.
  /// raised
  run conflictTest =
    start("staging", false, true, false, false, false).then(classify).then(writeStaging).then(compareWith(true))
      .expect(conflictReachesJoe and todoP1 and phase == "raised")

  /// R22: no yes, no change to a consolidated page.
  /// refused
  run noYesTest =
    start("consolidated", false, false, false, true, true).then(classify).then(askJoeWith(false))
      .expect(phase == "refused" and userTold and not(consolidatedChanged))

  /// R22, R4: a page with no root score is refused before the user is asked.
  run noScoreTest =
    start("consolidated", false, false, false, false, true).then(classify).then(askJoeWith(true))
      .expect(phase == "refused" and not(userTold) and not(consolidatedChanged))

  /// R22: a yes on a complete page writes it.
  run yesTest =
    start("consolidated", false, false, false, true, true).then(classify).then(askJoeWith(true))
      .expect(consolidatedChanged and safety)

  /// R25: a consolidated page changed through Bash is flagged, and the user is told.
  /// flagged
  run bashTest =
    start("consolidated", true, false, false, false, false).then(bashWrite)
      .expect(phase == "flagged" and consolidatedChanged and not(userYes) and safety)

  /// R21: a new source file with no date is refused.
  run noDateTest =
    start("source", false, true, false, false, false).then(classify).then(sourceWith(false))
      .expect(phase == "refused" and not(sourceChanged))

  /// R21: an existing source file is not rewritten without the user.
  run oldSourceTest =
    start("source", false, false, true, false, false).then(classify).then(sourceWith(false))
      .expect(phase == "refused")

  /// R9: an exempt file passes untouched by the checks.
  /// written
  run exemptTest =
    start("exempt", false, false, false, false, false).then(classify).expect(wrote and phase == "written")

  /// R22: every invariant holds along 10 random moves.
  run safetyTest = init.then(10.reps(_ => step)).expect(safety)
}

module kbPage {
  // A page at rest: its name and three nested headings.
  var suffix: str     // "source", "staging" or "" for a name with no area suffix
  var ext: str        // "md" or "media", any non-.md file
  var exempt: bool    // CLAUDE.md, a dot folder or plans/
  var rootScore: int  // 0 = none, else 1 to 3, from the frontmatter or the line under the title
  var h2Score: int
  var h3Score: int

  action init = {
    nondet s = Set("source", "staging", "").oneOf()
    nondet e = Set("md", "media").oneOf()
    nondet x = Set(true, false).oneOf()
    nondet r = 0.to(3).oneOf()
    nondet a = 0.to(3).oneOf()
    nondet b = 0.to(3).oneOf()
    all { suffix' = s, ext' = e, exempt' = x, rootScore' = r, h2Score' = a, h3Score' = b }
  }
  action step = all {
    suffix' = suffix, ext' = ext, exempt' = exempt, rootScore' = rootScore, h2Score' = h2Score, h3Score' = h3Score,
  }

  /// R9, R24: the area a name gives. A non-.md file with no suffix has none: the check flags it.
  pure def areaOf(s: str, e: str, x: bool): str =
    if (x) "exempt"
    else if (s != "") s
    else if (e == "md") "consolidated"
    else "none"

  /// R22: a heading with no score takes its parent's.
  pure def effective(own: int, parent: int): int = if (own > 0) own else parent

  val area = areaOf(suffix, ext, exempt)
  val h2Effective = effective(h2Score, rootScore)
  val h3Effective = effective(h3Score, h2Effective)

  /// R24, R22: the check passes a file only when it has an area, and a consolidated page only with a root score.
  val checkPasses = area != "none"
    and (area == "consolidated" implies rootScore > 0)

  /// R22: with a root score, every heading has a score.
  val rootCoversAll = (area == "consolidated" and rootScore > 0) implies (h2Effective > 0 and h3Effective > 0)

  // NEGATIVE CONTROL: false on purpose. Some files have no area.
  val everyFileHasArea = area != "none"

  /// R22: a heading's own score wins over its parent's.
  run ownScoreWinsTest =
    all { suffix' = "", ext' = "md", exempt' = false, rootScore' = 3, h2Score' = 1, h3Score' = 0 }
      .expect(h2Effective == 1 and h3Effective == 1 and checkPasses)

  /// R22: a consolidated page with no root score fails the check.
  run noRootScoreTest =
    all { suffix' = "", ext' = "md", exempt' = false, rootScore' = 0, h2Score' = 2, h3Score' = 0 }
      .expect(not(checkPasses))

  /// R24: a photo with no suffix fails the check. With .source. it passes.
  run photoTest =
    all { suffix' = "", ext' = "media", exempt' = false, rootScore' = 0, h2Score' = 0, h3Score' = 0 }
      .expect(not(checkPasses))
      .then(all { suffix' = "source", ext' = "media", exempt' = false, rootScore' = 0, h2Score' = 0, h3Score' = 0 })
      .expect(checkPasses)

  /// R22: every heading has a score.
  run rootCoversAllTest = init.expect(rootCoversAll)
}
