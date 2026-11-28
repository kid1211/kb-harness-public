// The findings page of one session: what each retro run writes, and what the user changes.
//
// The page is "none" before the first run, "cold" after a run that did not read the
// transcript, and "full" after a run that did. Each finding has a status. Only the user
// moves a status away from Open. A run again keeps every status, and adds new
// findings as Open. A cold run never takes the place of a full page.
//
// A run writes the page outside the KB first. The page moves into `personal` only if it
// matches no secret pattern, and only a page in `personal` is committed.
//
// Not modelled: the page text, the kinds, and whether a finding is right. A full page that
// was refused never reaches the KB, so a later cold run there writes a cold page: runCold
// guards the page in the KB, and a refused page is not one.
module findingsPage {
  type Status = Open | Confirmed | Dropped

  pure val IDS = Set(1, 2, 3)

  var page: str                    // "none", "cold" or "full"
  var status: int -> Status        // the findings on the page, by ID
  var secret: bool                 // the new page text matches a secret pattern
  var inKb: bool                   // the new page text is in `personal`
  var committed: bool              // the page in `personal` is in a commit
  var byUser: Set[int]              // the findings whose status the user set
  var everFull: bool               // a full page was written once

  action init = all {
    page' = "none", status' = Map(), secret' = false, inKb' = false, committed' = false, byUser' = Set(), everFull' = false,
  }

  /// R7: a run that read the transcript. New findings start open, old ones keep their status.
  action runFull = {
    nondet found = IDS.powerset().oneOf()
    nondet leak = Set(true, false).oneOf()
    all {
      Set("none", "cold", "full").contains(page),
      page' = "full",
      status' = found.union(status.keys()).mapBy(i => if (status.keys().contains(i)) status.get(i) else Open),
      secret' = leak, inKb' = false, committed' = false, byUser' = byUser, everFull' = true,
    }
  }

  /// R7: a cold run writes a one-line page, only where no full page is.
  action runCold = all {
    Set("none", "cold").contains(page),
    page' = "cold", status' = status, secret' = false, inKb' = false, committed' = false, byUser' = byUser, everFull' = everFull,
  }

  /// R2: a page that matches a secret pattern never moves into `personal`.
  action moveIn = all {
    page != "none", not(secret), not(inKb),
    inKb' = true, page' = page, status' = status, secret' = secret, committed' = false, byUser' = byUser, everFull' = everFull,
  }

  /// R2: the commit script commits only a page in `personal`, and checks it again.
  action commit = all {
    inKb, not(secret), not(committed),
    committed' = true, page' = page, status' = status, secret' = secret, inKb' = inKb, byUser' = byUser, everFull' = everFull,
  }

  /// R5: only the user changes a status, and only on an open finding of a page in `personal`.
  action userSets = {
    nondet i = IDS.oneOf()
    nondet s = Set(Confirmed, Dropped).oneOf()
    all {
      inKb, status.keys().contains(i), status.get(i) == Open,
      status' = status.set(i, s), byUser' = byUser.union(Set(i)),
      page' = page, secret' = secret, inKb' = inKb, committed' = false, everFull' = everFull,
    }
  }

  /// R7: a finished page stays as it is.
  action done = all {
    page' = page, status' = status, secret' = secret, inKb' = inKb, committed' = committed, byUser' = byUser, everFull' = everFull,
  }

  action step = any { runFull, runCold, moveIn, commit, userSets, done }

  /// R7: once a full page is written, the page stays full. A cold run never takes its place.
  val fullStaysFull = everFull implies page == "full"
  /// R2: a page in `personal` has no secret, so no commit can hold one.
  val kbHasNoSecret = inKb implies not(secret)
  /// R5: a finding not open was set by the user.
  val onlyUserSets = status.keys().forall(i => status.get(i) != Open implies byUser.contains(i))
  /// R7: a cold page holds no findings.
  val coldHasNoFindings = page == "cold" implies status.keys() == Set()
  /// NEGATIVE CONTROL: false on purpose. The user confirms a finding, so not every finding stays open.
  val allStayOpen = status.keys().forall(i => status.get(i) == Open)

  /// R2: a page with a secret does not move into `personal`.
  run secretPageStaysOutTest = {
    init
      .then(all { page' = "full", status' = Map(1 -> Open), secret' = true, inKb' = false, committed' = false, byUser' = Set(), everFull' = true })
      .then(moveIn)
      .fail()
  }
  /// R2: a clean page moves in and is committed.
  run cleanPageCommittedTest = {
    init
      .then(all { page' = "full", status' = Map(1 -> Open), secret' = false, inKb' = false, committed' = false, byUser' = Set(), everFull' = true })
      .then(moveIn)
      .then(commit)
      .expect(committed and kbHasNoSecret)
  }
  /// R5: in any run, only the user set a status.
  run onlyUserSetsTest = init.then(12.reps(_ => step)).expect(onlyUserSets and kbHasNoSecret and fullStaysFull)
  /// R7: a cold run after a full run cannot happen.
  run coldAfterFullFailsTest = init.then(runFull).then(runCold).fail()
  /// R7: a run again keeps the status the user set.
  /// full
  run rerunKeepsStatusTest = {
    init
      .then(all { page' = "full", status' = Map(1 -> Confirmed), secret' = false, inKb' = true, committed' = false, byUser' = Set(1), everFull' = true })
      .then(runFull)
      .expect(status.get(1) == Confirmed)
  }
}
