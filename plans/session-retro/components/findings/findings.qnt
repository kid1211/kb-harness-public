// The findings part of session-retro: findings.py scans the transcript for candidates, the fork of
// the session judges them, and findings.py check keeps the findings that are real. States are the
// state nodes of architecture.md.
//
// A candidate is a group of one kind and subject, from a block, a loop or a turn of the user. The fork
// returns an ordered list of findings. It may leave a candidate out (R8), add its own, and hold a
// kind not on the list, a uuid not in the transcript, a verdict that breaks R6, or any `unseen`.
// check drops the first two kinds of bad finding, takes `unseen` from the scan (R9), sets `unknown`
// on an unseen block, and keeps the first finding of each ID (R10).
//
// Not modelled, held by the unit tests: the shapes of the transcript, the text of a candidate, and
// whether the fork judged a block or a correction right.
module findings {
  type Finding = { kind: str, subject: str, uuid: int, right: str, unseen: bool }

  pure val KINDS = Set("hook_block", "guard_block", "repeated_call", "misunderstood_request")  // findings-kinds.md
  pure val UUIDS = Set(1, 2, 3)                                    // events of the transcript
  pure val BLOCKS = Set("hook_block", "guard_block")
  pure val VERDICTS = Set("yes", "no", "unknown")
  pure val RAW_KINDS = KINDS.union(Set("made_up", "none"))         // "none": no finding at that place of the reply
  pure val RAW_UUIDS = UUIDS.union(Set(9))
  pure val PLACES = Set(0, 1, 2)                                   // the places of the fork's reply
  pure val BLANK = { kind: "none", subject: "a", uuid: 1, right: "unknown", unseen: false }

  var phase: str                // "scan", "judge", "findings_json"
  var candidates: Set[Finding]  // what the scan lists
  var raw: int -> Finding       // what the fork returns, by place, before check
  var checked: bool             // check ran
  var out: Set[Finding]         // the list findings-page.py writes

  pure def isReal(f: Finding): bool = f.kind != "none"
  pure def sameId(f: Finding, g: Finding): bool = f.kind == g.kind and f.subject == g.subject and f.uuid == g.uuid
  pure def valid(f: Finding): bool = isReal(f) and KINDS.contains(f.kind) and UUIDS.contains(f.uuid)
  // R10: a finding stays only if no earlier valid place holds its ID.
  pure def firstOfId(r: int -> Finding, p: int): bool =
    PLACES.filter(q => q < p).forall(q => not(valid(r.get(q)) and sameId(r.get(q), r.get(p))))
  // R9: unseen is the scan's, found by uuid and kind. The fork's own flag is ignored.
  pure def scanUnseen(cs: Set[Finding], f: Finding): bool =
    cs.exists(c => c.kind == f.kind and c.uuid == f.uuid and c.unseen)
  pure def fixed(cs: Set[Finding], f: Finding): Finding =
    if (BLOCKS.contains(f.kind) and scanUnseen(cs, f)) { ...f, right: "unknown", unseen: true }
    else { ...f, unseen: scanUnseen(cs, f) }
  pure def reply(a: Finding, b: Finding, c: Finding): int -> Finding = Map(0 -> a, 1 -> b, 2 -> c)

  action init = all {
    phase' = "scan", candidates' = Set(), raw' = PLACES.mapBy(_ => BLANK),
    checked' = false, out' = Set(),
  }

  /// R7, R2, R3: the scan lists a candidate for each kind and subject it finds. A block before the last compaction is unseen.
  action scan = {
    nondet cs = tuples(KINDS, Set("a", "b"), UUIDS, Set(true, false)).powerset().oneOf()
    all {
      phase == "scan",
      phase' = "judge",
      candidates' = cs.map(t => { kind: t._1, subject: t._2, uuid: t._3, right: "unknown", unseen: t._4 }),
      raw' = raw, checked' = checked, out' = out,
    }
  }

  /// R8, R6, R4, R9: the fork returns any ordered list it likes: it may leave a candidate out, add its own, and give a bad kind, a bad uuid, any verdict and any unseen.
  action judge = {
    nondet r = PLACES.setOfMaps(tuples(RAW_KINDS, Set("a", "b"), RAW_UUIDS, VERDICTS, Set(true, false)).map(t => { kind: t._1, subject: t._2, uuid: t._3, right: t._4, unseen: t._5 })).oneOf()
    all {
      phase == "judge",
      phase' = "findings_json",
      raw' = r,
      candidates' = candidates, checked' = checked, out' = out,
    }
  }

  /// R4, R6, R9, R10: check drops a bad kind and a bad uuid, takes unseen from the scan, sets `unknown` on an unseen block, and keeps the first of each ID.
  action check = all {
    phase == "findings_json",
    not(checked),
    out' = PLACES.filter(p => valid(raw.get(p)) and firstOfId(raw, p)).map(p => fixed(candidates, raw.get(p))),
    checked' = true,
    phase' = phase, candidates' = candidates, raw' = raw,
  }

  /// R7: a finished run stays as it is. It ends only after check.
  action done = all { phase == "findings_json", checked, phase' = phase, candidates' = candidates, raw' = raw, checked' = checked, out' = out }

  action step = any { scan, judge, check, done }

  val rawFindings = PLACES.filter(p => isReal(raw.get(p))).map(p => raw.get(p))

  /// R4: each finding has a kind from the fixed list.
  val onlyListedKinds = out.forall(f => KINDS.contains(f.kind))
  /// R4: each finding has a uuid in the transcript.
  val uuidInTranscript = out.forall(f => UUIDS.contains(f.uuid))
  /// R6: a finding of an unseen block says `unknown`.
  val unseenIsUnknown = out.forall(f => (BLOCKS.contains(f.kind) and f.unseen) implies f.right == "unknown")
  /// R9: the unseen flag of a finding is the scan's, whatever the fork wrote.
  val unseenFromScan = out.forall(f => f.unseen == scanUnseen(candidates, f))
  /// R7, R8: a finding comes from the fork's reply. check adds none, and a candidate the fork left out is not in out.
  val outFromFork = out.forall(f => rawFindings.exists(r => sameId(r, f)))
  /// R10: each ID is in the list once.
  val oneIdEach = out.forall(f => out.forall(g => sameId(f, g) implies f == g))
  /// NEGATIVE CONTROL: false on purpose. The fork can return a bad kind, and check drops it, so out is not always all of the reply.
  val checkKeepsAll = checked implies out.size() == rawFindings.size()

  /// R4: a made-up kind and a uuid outside the transcript are dropped.
  /// findings_json
  run dropBadTest = {
    init
      .then(all { phase' = "findings_json", candidates' = Set(), out' = Set(), checked' = false,
        raw' = reply({ kind: "made_up", subject: "a", uuid: 1, right: "yes", unseen: false }, { kind: "hook_block", subject: "a", uuid: 9, right: "yes", unseen: false }, { kind: "hook_block", subject: "b", uuid: 2, right: "no", unseen: false }) })
      .then(check)
      .expect(out.size() == 1 and onlyListedKinds and uuidInTranscript)
  }
  /// R6, R9: an unseen block gets `unknown` and unseen true from the scan, even if the fork said `yes` and `unseen: false`.
  run unseenTest = {
    init
      .then(all { phase' = "findings_json", candidates' = Set({ kind: "guard_block", subject: "a", uuid: 1, right: "unknown", unseen: true }), out' = Set(), checked' = false,
        raw' = reply({ kind: "guard_block", subject: "a", uuid: 1, right: "yes", unseen: false }, BLANK, BLANK) })
      .then(check)
      .expect(unseenIsUnknown and unseenFromScan and out.size() == 1)
  }
  /// R8: a candidate the fork does not return is not a finding.
  run dropCandidateTest = {
    init
      .then(all { phase' = "findings_json", candidates' = Set({ kind: "hook_block", subject: "a", uuid: 1, right: "unknown", unseen: false }), out' = Set(), checked' = false,
        raw' = reply(BLANK, BLANK, BLANK) })
      .then(check)
      .expect(out.size() == 0 and outFromFork)
  }
  /// R10: two findings with one ID give one finding, the first.
  run oneIdTest = {
    init
      .then(all { phase' = "findings_json", candidates' = Set(), out' = Set(), checked' = false,
        raw' = reply({ kind: "hook_block", subject: "a", uuid: 1, right: "yes", unseen: false }, { kind: "hook_block", subject: "a", uuid: 1, right: "no", unseen: false }, BLANK) })
      .then(check)
      .expect(out.size() == 1 and oneIdEach and out.forall(f => f.right == "yes"))
  }
  /// R7: in any run, the invariants hold.
  run invariantsTest = init.then(12.reps(_ => step)).expect(onlyListedKinds and uuidInTranscript and unseenIsUnknown and unseenFromScan and outFromFork and oneIdEach)
}
