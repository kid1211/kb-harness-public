// writing-mode: the mode buttons of the writing-check, on the top row of the band.
//
// The states are the state nodes of architecture.md, the source of truth:
// start, read_modes, pass_on, draw_row, cycle, compose, toggle_pane, close_pane. The decisions event?
// and survey? pick the next state. 1-design.md explains each state.
//
// file is the mode file as the mod reads it: one value per kind, or "bad" for a
// value that is not a mode, a missing one, or a file that does not parse.
// rows is the band as drawn, top first. "below" stands for the tree of next(e)
// beneath both harness mods. outer is the harness mod that loads first. If it is
// "rounds", plan-rounds draws the tree of this mod first and its "rounds" row
// last (R2 of pane-button). If it is "writing", the tree of next(e) of this mod
// is the band of plan-rounds: the tree beneath, then the "rounds" row.

module writingMode {
  val MODES = Set("off", "casual", "pro")
  val KINDS = Set("reply", "docs")
  val VALUES = MODES.union(Set("bad"))
  def nextMode(m: str): str = if (m == "off") "casual" else if (m == "casual") "pro" else "off"
  def norm(v: str): str = if (MODES.contains(v)) v else "pro"

  var phase: str
  // The event: draw, press or prompt.
  var event: str
  // The kind of mode a press moves.
  var pressed: str
  // A survey holds the band.
  var survey: bool
  // next(e) beneath both harness mods gives a tree.
  var below: bool
  // The harness mod that loads first: writing or rounds.
  var outer: str
  // The mode file, per kind.
  var file: str -> str
  // The modes as read this time.
  var modes: str -> str
  // The band, top first.
  var rows: List[str]
  // The casual sections added to the system prompt.
  var sections: Set[str]
  // The writing-check pane is open, and was open when the event came.
  var pane: bool
  var paneBefore: bool

  /// R1: move start with.
  action startWith(ev: str, k: str, s: bool, b: bool, o: str, r: str, d: str): bool = openWith(ev, k, s, b, o, r, d, false)
  /// R1: move open with.
  action openWith(ev: str, k: str, s: bool, b: bool, o: str, r: str, d: str, p: bool): bool = all {
    phase' = "start", event' = ev, pressed' = k, survey' = s, below' = b, outer' = o,
    file' = Map("reply" -> r, "docs" -> d), modes' = Map(), rows' = [], sections' = Set(),
    pane' = p, paneBefore' = p,
  }
  action init = {
    nondet ev = Set("draw", "press", "prompt", "config", "other").oneOf()
    nondet k = KINDS.oneOf()
    nondet s = Set(true, false).oneOf()
    nondet b = Set(true, false).oneOf()
    nondet o = Set("writing", "rounds").oneOf()
    nondet r = VALUES.oneOf()
    nondet d = VALUES.oneOf()
    nondet p = Set(true, false).oneOf()
    openWith(ev, k, s, b, o, r, d, p)
  }

  action keep = all { event' = event, pressed' = pressed, survey' = survey, below' = below, outer' = outer, paneBefore' = paneBefore }
  action keepPane = pane' = pane

  // The tree beneath both harness mods.
  def beneath: List[str] = if (below) ["below"] else []
  // The band of this mod: with plan-rounds inside it when this mod is the outer one.
  def inner(own: List[str]): List[str] = if (outer == "writing") own.concat(beneath).concat(["rounds"]) else own.concat(beneath)
  // The whole band: plan-rounds puts the tree of next(e) first, its own row last.
  def band(own: List[str]): List[str] = if (outer == "rounds") inner(own).concat(["rounds"]) else inner(own)

  /// R8: each event reads the file again, and a bad value is pro.
  action readModes = all {
    phase == "start", keep, keepPane, file' = file, rows' = rows, sections' = sections,
    phase' = "read_modes", modes' = KINDS.mapBy(k => norm(file.get(k))),
  }
  /// R10: a survey holds the band, so the mod draws nothing of its own.
  action passOn = all {
    phase == "read_modes", event == "draw", survey, keep, keepPane, file' = file, modes' = modes, sections' = sections,
    phase' = "pass_on", rows' = beneath,
  }
  /// R9, R10: the own row on top, then the tree of next(e).
  action drawRow = all {
    phase == "read_modes", event == "draw", not(survey), keep, keepPane, file' = file, modes' = modes, sections' = sections,
    phase' = "draw_row", rows' = band(["writing"]),
  }
  /// R1, R8: the pressed mode moves on from the file, and the other mode is written as the file had it.
  action cycle = all {
    phase == "read_modes", event == "press", keep, keepPane, modes' = modes, rows' = rows, sections' = sections,
    phase' = "cycle", file' = modes.set(pressed, nextMode(modes.get(pressed))),
  }
  /// R2, R8: a casual section for each kind in casual mode, from the file as read now.
  action compose = all {
    phase == "read_modes", event == "prompt", keep, keepPane, file' = file, modes' = modes, rows' = rows,
    phase' = "compose", sections' = KINDS.filter(k => modes.get(k) == "casual"),
  }
  /// R2: move stay.
  action stay = all {
    Set("pass_on", "draw_row", "cycle", "compose", "toggle_pane", "close_pane").contains(phase),
    keep, keepPane, file' = file, modes' = modes, rows' = rows, sections' = sections, phase' = phase,
  }
  /// R12: a press of config opens the pane if it is closed, and closes it if it is open.
  action togglePane = all {
    phase == "read_modes", event == "config", keep, file' = file, modes' = modes, rows' = rows, sections' = sections,
    phase' = "toggle_pane", pane' = not(pane),
  }
  /// R10 of the mod level: another harness mod opens its pane, so this mod closes its own.
  action closePane = all {
    phase == "read_modes", event == "other", keep, file' = file, modes' = modes, rows' = rows, sections' = sections,
    phase' = "close_pane", pane' = false,
  }
  action step = any { readModes, passOn, drawRow, cycle, compose, togglePane, closePane, stay }

  val read = phase != "start"

  /// R8: the modes in use are the file's, with each bad value as pro.
  val modesFromFile = (read and phase != "cycle") implies KINDS.forall(k => modes.get(k) == norm(file.get(k)))
  /// R8: a written file holds only modes.
  val fileWrittenClean = phase == "cycle" implies KINDS.forall(k =>
    file.get(k) == (if (k == pressed) nextMode(modes.get(k)) else modes.get(k)) and MODES.contains(file.get(k))
  )
  /// R9: the writing-mode row is the top row, in either load order.
  val ownRowFirst = phase == "draw_row" implies rows[0] == "writing"
  /// R10: the tree beneath shows, once, and the rounds row shows once.
  val belowKept = Set("pass_on", "draw_row").contains(phase) implies all {
    rows.select(r => r == "below").length() == (if (below) 1 else 0),
    phase == "draw_row" implies rows.select(r => r == "rounds").length() == 1,
  }
  /// R10: no own row while a survey holds the band.
  val noRowInSurvey = survey implies rows.select(r => r == "writing").length() == 0
  /// R2: a casual section for each kind in casual mode, and for no other.
  val casualOnly = phase == "compose" implies sections == KINDS.filter(k => modes.get(k) == "casual")

  /// R12: a press of config flips the pane, open to closed and closed to open.
  val configToggles = phase == "toggle_pane" implies pane != paneBefore
  /// R10 of the mod level: when another pane opens, this pane is closed.
  val onePane = phase == "close_pane" implies not(pane)
  /// R12: only a press of config or another pane changes the pane.
  val paneOnlyByConfig = not(Set("toggle_pane", "close_pane").contains(phase)) implies pane == paneBefore

  val allInvariants = and {
    modesFromFile, fileWrittenClean, ownRowFirst, belowKept, noRowInSurvey,
    casualOnly, configToggles, onePane, paneOnlyByConfig,
  }

  // NEGATIVE CONTROL: false on purpose. A press can move a mode.
  val neverCycles = phase != "cycle"

  /// R12: run draw.
  /// draw_row
  run drawTest = startWith("draw", "reply", false, true, "writing", "pro", "off").then(readModes).then(drawRow)
    .expect(rows == ["writing", "below", "rounds"])
  /// R10: run alone.
  run aloneTest = startWith("draw", "reply", false, false, "writing", "pro", "pro").then(readModes).then(drawRow).expect(rows == ["writing", "rounds"])
  /// R10: run survey.
  /// pass_on
  run surveyTest = startWith("draw", "reply", true, true, "writing", "pro", "pro").then(readModes).then(passOn).expect(rows == ["below"])
  /// R8: run bad.
  run badTest = startWith("draw", "reply", false, false, "writing", "bad", "casual").then(readModes)
    .expect(modes.get("reply") == "pro" and modes.get("docs") == "casual")
  /// R8: run cycle.
  /// cycle
  run cycleTest = startWith("press", "reply", false, false, "writing", "casual", "off").then(readModes).then(cycle)
    .expect(file.get("reply") == "pro" and file.get("docs") == "off")
  /// R8: run cycle bad.
  run cycleBadTest = startWith("press", "docs", false, false, "writing", "bad", "pro").then(readModes).then(cycle)
    .expect(file.get("reply") == "pro" and file.get("docs") == "off")
  /// R8: run compose.
  /// compose
  run composeTest = startWith("prompt", "reply", false, false, "writing", "casual", "pro").then(readModes).then(compose)
    .expect(sections == Set("reply"))
  /// R9: with plan-rounds as the outer mod, the writing-mode row is still on top.
  run roundsOuterTest = startWith("draw", "reply", false, true, "rounds", "pro", "pro").then(readModes).then(drawRow)
    .expect(rows == ["writing", "below", "rounds"])
  /// R12: config opens a closed pane, and closes an open one.
  /// toggle_pane
  run toggleTest = openWith("config", "reply", false, false, "writing", "pro", "pro", false).then(readModes).then(togglePane).expect(pane)
  /// R12: run toggle close.
  run toggleCloseTest = openWith("config", "reply", false, false, "writing", "pro", "pro", true).then(readModes).then(togglePane).expect(not(pane))
  /// R10 of the mod level: another pane opens, so this one closes.
  /// close_pane
  run onePaneTest = openWith("other", "reply", false, false, "writing", "pro", "pro", true).then(readModes).then(closePane).expect(not(pane))
  /// R10: run safety.
  run safetyTest = init.then(3.reps(_ => step)).expect(
    modesFromFile and fileWrittenClean and ownRowFirst and belowKept and noRowInSurvey and casualOnly
      and configToggles and onePane and paneOnlyByConfig
  )
}
