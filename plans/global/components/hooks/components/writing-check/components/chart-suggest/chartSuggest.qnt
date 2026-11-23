// The chart note of writing-check: one state per state node of architecture.md.

module chartSuggest {
  var phase: str
  var logged: int       // how many times the missing catalog was logged in this run
  var matches: int      // rows of the signal table that the edit matched
  var blocked: bool     // the edit was sent back to fix
  var noted: bool       // Claude got a chart note

  action init = all {
    phase' = "edit", logged' = 0, matches' = 0, blocked' = false, noted' = false,
  }

  /// R5: with the docs mode off, or on the catalog page itself, the edit ends with no note.
  action editSkipped = all {
    phase == "edit", phase' = "done",
    logged' = logged, matches' = matches, blocked' = blocked, noted' = noted,
  }

  /// R5: with no catalog page, the check says so once in the log and suggests nothing.
  action editNoCatalog = all {
    phase == "edit", phase' = "missing", logged' = 1,
    matches' = matches, blocked' = blocked, noted' = noted,
  }

  /// R5: the missing page ends the check with no note.
  action missingEnds = all {
    phase == "missing", phase' = "done",
    logged' = logged, matches' = matches, blocked' = blocked, noted' = noted,
  }

  /// R7: the check reads the signal table of the catalog page.
  action editReads = all {
    phase == "edit", phase' = "read_signals",
    logged' = logged, matches' = matches, blocked' = blocked, noted' = noted,
  }

  /// R7: the signal table is read, and the scan follows.
  action readDone = all {
    phase == "read_signals", phase' = "scan",
    logged' = logged, matches' = matches, blocked' = blocked, noted' = noted,
  }

  /// R7, R9: the scan counts the rows that match. A missing or large or iCloud-only file counts none.
  action scanDone(n: int): bool = all {
    phase == "scan", n >= 0 and n <= 5, matches' = n,
    phase' = if (n > 0) "note" else "done",
    logged' = logged, blocked' = blocked, noted' = noted,
  }

  /// R5: the note is advice. It never blocks the edit.
  action noteSent = all {
    phase == "note", phase' = "done", noted' = true,
    logged' = logged, matches' = matches, blocked' = blocked,
  }

  /// R5: an ended run stays as it is, so the checker sees no deadlock.
  action ended = all { Set("done", "missing").contains(phase), keep }

  action step = any {
    editSkipped, editNoCatalog, missingEnds, editReads, readDone, noteSent, ended,
    nondet n = 0.to(5).oneOf()
    scanDone(n),
  }

  /// R5: a chart note never blocks the edit.
  val noteNeverBlocks = not(blocked)

  /// R5: a missing catalog is logged at most once.
  val missingLoggedOnce = logged <= 1

  /// R7: a note needs a matched row of the signal table.
  val noteNeedsMatch = noted implies matches > 0

  val allInvariants = noteNeverBlocks and missingLoggedOnce and noteNeedsMatch

  // NEGATIVE CONTROL: false on purpose, an edit does get a note
  val neverNotes = not(noted)

  /// R5: a helper that keeps every variable, for the asserts of the runs.
  action keep = all {
    phase' = phase, logged' = logged, matches' = matches, blocked' = blocked, noted' = noted,
  }

  /// R5: an edit with a match gets a note, and the edit is not blocked.
  /// done
  run notedTest = init.then(editReads).then(readDone).then(scanDone(2)).then(noteSent).then(all {
    assert(phase == "done" and noted and not(blocked)), keep,
  })

  /// R7: an edit with no match ends quiet.
  run quietTest = init.then(editReads).then(readDone).then(scanDone(0)).then(all {
    assert(phase == "done" and not(noted)), keep,
  })

  /// R5: a missing catalog is logged once and suggests nothing.
  run missingTest = init.then(editNoCatalog).then(missingEnds).then(all {
    assert(phase == "done" and not(noted) and logged == 1), keep,
  })

  /// R5: the docs mode off ends at once.
  run offTest = init.then(editSkipped).then(all {
    assert(phase == "done" and not(noted)), keep,
  })
}
