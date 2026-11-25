// The local e2e: test folders next to the harness, then real sessions on them, one line per check.
module localE2e {
  // The checks the e2e runs. Each one becomes one `ok` or `not ok` line.
  pure val checks = Set("skill-web", "skill-api", "skill-b", "instructions-web", "worktree")

  var phase: str          // asked, made, ran, reported
  var folders: Set[str]   // the test folders on disk
  var stale: bool         // a file from an earlier run is left in the test folders
  var mapRead: str        // the map the sessions read: "test" or "real"
  var lines: Set[str]     // the checks that printed a line

  action keep(p: str, f: Set[str], s: bool, m: str, l: Set[str]): bool =
    all { phase' = p, folders' = f, stale' = s, mapRead' = m, lines' = l }

  /// F1: an earlier run may have left files.
  action initWith(s: bool): bool = keep("asked", if (s) Set("folder-a", "folder-b", "kb") else Set(), s, "", Set())
  action init = nondet s = Set(true, false).oneOf() initWith(s)

  /// F1: the fixture command makes the three folders fresh.
  action make = all { phase == "asked", keep("made", Set("folder-a", "folder-b", "kb"), false, "", Set()) }
  /// F2, F3: the sessions start through project-start, on the map of the test folders.
  action run_ = all { phase == "made", keep("ran", folders, stale, "test", lines) }
  /// F3: one line per check.
  action report = all { phase == "ran", keep("reported", folders, stale, mapRead, checks) }
  /// F3: the run ends at the report.
  action done = all { phase == "reported", keep(phase, folders, stale, mapRead, lines) }

  action step = any { make, run_, report, done }

  /// F1: after the make, the three folders are there and nothing old is left.
  val madeFresh = phase != "asked" implies (folders == Set("folder-a", "folder-b", "kb") and not(stale))
  /// F2: the sessions never read the real map.
  val neverRealMap = mapRead != "real"
  /// F3: a report has one line per check.
  val oneLinePerCheck = phase == "reported" implies lines == checks
  /// NEGATIVE CONTROL: a run does report.
  val neverReports = phase != "reported"

  /// F1, F3: from an old run to a report.
  /// reported
  run reportTest = initWith(true).then(make).then(run_).then(report)
    .expect(lines == checks and mapRead == "test" and not(stale))
}
