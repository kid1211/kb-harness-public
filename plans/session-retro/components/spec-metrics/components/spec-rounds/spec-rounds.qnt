// The spec rounds of one session: what spec-rounds.py records after the retro page is in the KB.
//
// A round is the work between two automatic plan commits of the session. The script finds the
// rounds of the session, puts its rows in spec-rounds.csv in place of its old rows, and writes
// the Spec section of the page from those rows and the medians of all rows. A session with no
// round gets no rows and no section. A run again gives the same file and page.
//
// Not modelled: how each number is counted from the transcript, the page text, and the commit.
// Each metric is a count or minutes where more is worse, so "worse" is "above the median".
module specRounds {
  pure val COUNTS = Set(0, 1, 2, 3)

  var phase: str                 // a state node of architecture.md
  var found: int                 // the rounds of session "a" found in its transcript
  var rows: str -> int           // rows of spec-rounds.csv, by session
  var section: bool              // the page of session "a" has a Spec section
  var runs: int                  // how many times record ran on session "a"

  action init = {
    nondet other = COUNTS.oneOf()
    all { phase' = "start", found' = 0, rows' = Map("b" -> other), section' = false, runs' = 0 }
  }

  /// F1: the script reads the transcript and finds the rounds of session "a". A run again finds the same rounds.
  action scanTo(n: int): bool = all {
    Set("start", "recorded", "skipped").contains(phase), runs < 2,
    phase' = "scanned", found' = if (runs == 0) n else found, rows' = rows, section' = section, runs' = runs + 1,
  }

  /// F1: the scan finds any number of rounds.
  action scan = {
    nondet n = COUNTS.oneOf()
    scanTo(n)
  }

  /// F1: with no transcript, the run fails and the rows stay as they were.
  action noTranscript = all {
    phase == "start", phase' = "failed", found' = found, rows' = rows, section' = section, runs' = runs,
  }

  /// F4: a session with no round gets no row and no section.
  action skip = all {
    phase == "scanned", found == 0,
    phase' = "skipped", rows' = rows, section' = false, found' = found, runs' = runs,
  }

  /// F1, F4: the rows of the session take the place of its old rows, and the Spec section the old one.
  /// Other sessions keep their rows.
  action writeRows = all {
    phase == "scanned", found > 0,
    phase' = "written", rows' = rows.put("a", found), section' = true, found' = found, runs' = runs,
  }

  /// F1: a write error fails the run and writes nothing. The page still goes in, as it was.
  action writeFails = all {
    phase == "scanned", phase' = "failed", rows' = rows, section' = section, found' = found, runs' = runs,
  }

  /// F4: commit-page.sh takes the page and spec-rounds.csv together.
  action record = all {
    phase == "written", phase' = "recorded", rows' = rows, section' = section, found' = found, runs' = runs,
  }

  /// F1: a finished run stays as it is.
  action done = all { phase' = phase, rows' = rows, section' = section, found' = found, runs' = runs }

  action step = any { scan, noTranscript, skip, writeRows, writeFails, record, done }

  /// F1: a written session has one row per round found, never more, so a run again adds nothing.
  val oneRowPerRound = Set("written", "recorded").contains(phase) implies rows.get("a") == found

  /// F1: the rows of another session never go away.
  val otherRowsKept = rows.keys().contains("b")

  /// F4: a recorded page has a Spec section, and a skipped page has none.
  val sectionIffRounds = (phase == "recorded" implies section) and (phase == "skipped" implies not(section))

  /// F4: a section is only on a page of a session that has rows.
  val sectionHasRows = section implies (rows.keys().contains("a") and rows.get("a") > 0)

  /// NEGATIVE CONTROL: false on purpose, a session can be skipped.
  val neverSkipped = phase != "skipped"

  /// recorded
  /// F1, F4: a session with rounds ends with its rows and its section.
  run recordedTest = init.then(scanTo(2)).then(writeRows).then(record)
    .expect(phase == "recorded" and section and oneRowPerRound)

  /// skipped
  /// F4: a session with no round gets no row and no section.
  run skippedTest = init.then(scanTo(0)).then(skip)
    .expect(phase == "skipped" and not(section) and not(rows.keys().contains("a")))

  /// failed
  /// F1: no transcript fails the run.
  run failedTest = init.then(noTranscript).expect(phase == "failed")

  /// F1: a run again on the same session gives the same rows.
  run againTest = init.then(scanTo(2)).then(writeRows).then(record)
    .then(scan).then(writeRows).expect(rows.get("a") == 2)
}
