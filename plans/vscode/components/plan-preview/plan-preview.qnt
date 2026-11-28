// plan-preview: what a click or a hover does in the Markdown preview of a plan. There is no big
// hover card (R2). A small card shows the first sentence of an answer (R416); its text and size are
// held by the node tests.
// The marks of R7 are render output with no state: the node tests check them.
// ui is the one popup, card or fold the reader has open. statesOnly is the setting.
// fileFeedback and fileReason are the two fields in the answer page on disk.
// feedback and reason are what the preview shows. Every pick writes both together.
module planPreview {
  val VALUES = Set("agree", "disagree", "not_checked")
  val REASONS = Set("too broad", "no source")

  var ui: str            // "reading", "part_open", "popup", "reason_input", "card", "closed"
  var statesOnly: bool
  var feedback: str
  var reason: str
  var fileFeedback: str
  var fileReason: str

  /// R1: a step that changes nothing.
  action unchanged = all {
    ui' = ui, statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }

  action init = all {
    ui' = "reading",
    statesOnly' = false,
    feedback' = "not_checked",
    reason' = "",
    fileFeedback' = "not_checked",
    fileReason' = "",
  }

  /// R1: a click on a part opens it, a second click folds it. No part exists in the states-only view.
  action clickPart = all {
    not(statesOnly),
    Set("reading", "closed", "part_open").contains(ui),
    ui' = if (ui == "part_open") "reading" else "part_open",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }

  /// R2: a click on the link opens the popup.
  action openPopup = all {
    Set("reading", "closed", "card").contains(ui),
    ui' = "popup",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }
  /// R416: a hover on the text of a question shows the small card. It writes nothing.
  action hoverCard = all {
    Set("reading", "closed").contains(ui),
    ui' = "card",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }
  /// R416: the pointer leaves, and the card goes.
  action leaveCard = all {
    ui == "card",
    ui' = "reading",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }
  /// R2: Esc, a click outside or the close button ends the popup.
  action closePopup = all {
    ui == "popup",
    ui' = "closed",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }

  /// R3: agree and not checked write at once, and keep the reason for a later disagree.
  action pick(v: str): bool = all {
    ui == "popup",
    v == "agree" or v == "not_checked",
    feedback' = v, fileFeedback' = v,
    reason' = reason, fileReason' = fileReason,
    ui' = "popup", statesOnly' = statesOnly,
  }

  /// R3: disagree first asks for a reason. Nothing is written until the reason comes.
  action pickDisagree = all {
    ui == "popup",
    ui' = "reason_input",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }
  /// R3: the reason comes, and both fields are written.
  action sendReason(r: str): bool = all {
    ui == "reason_input",
    REASONS.contains(r),
    feedback' = "disagree", fileFeedback' = "disagree",
    reason' = r, fileReason' = r,
    ui' = "popup", statesOnly' = statesOnly,
  }
  /// R3: a cancel writes nothing.
  action cancelReason = all {
    ui == "reason_input",
    ui' = "popup",
    statesOnly' = statesOnly, feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }

  /// R4: the setting renders the page again, so nothing is open after it changes.
  action setStatesOnly(b: bool): bool = all {
    statesOnly' = b,
    ui' = "reading",
    feedback' = feedback, reason' = reason,
    fileFeedback' = fileFeedback, fileReason' = fileReason,
  }

  action step = any {
    clickPart, openPopup, closePopup, hoverCard, leaveCard,
    nondet v = VALUES.oneOf() pick(v),
    pickDisagree, cancelReason,
    nondet r = REASONS.oneOf() sendReason(r),
    nondet b = Set(true, false).oneOf() setStatesOnly(b),
  }

  /// R1, R4: no part is open in the states-only view.
  val noPartInStatesOnly = statesOnly implies ui != "part_open"
  /// R3: the preview shows what the answer page holds.
  val fileMatchesPreview = fileFeedback == feedback and fileReason == reason
  /// R3: a disagree on disk always has a reason.
  val disagreeHasReason = fileFeedback == "disagree" implies fileReason != ""
  /// R2: the preview is always in one of its six states.
  val uiKnown = Set("reading", "part_open", "popup", "reason_input", "closed", "card").contains(ui)
  /// R2: NEGATIVE CONTROL, false on purpose: the popup does open.
  val neverPopup = ui != "popup"

  /// R1, F1: read a design, open a part, fold it.
  run foldTest = init.then(clickPart).then(all { assert(ui == "part_open"), clickPart }).then(all { assert(ui == "reading"), unchanged })
  /// R2, F2: click, read, close.
  /// closed
  run openAnswerTest = init.then(openPopup).then(all { assert(ui == "popup"), closePopup }).then(all { assert(ui == "closed"), unchanged })
  /// R3, F3: disagree with a reason, then agree. The reason stays.
  run feedbackTest = init.then(openPopup).then(pickDisagree).then(all { assert(fileFeedback == "not_checked"), sendReason("no source") })
    .then(all { assert(fileFeedback == "disagree" and fileReason == "no source"), pick("agree") })
    .then(all { assert(fileFeedback == "agree" and fileReason == "no source"), unchanged })
  /// R4, F4: the setting hides the parts, and a part cannot open.
  run statesOnlyTest = init.then(clickPart).then(setStatesOnly(true)).then(all { assert(ui == "reading" and statesOnly), openPopup })
    .then(all { assert(ui == "popup" and noPartInStatesOnly), unchanged })
  /// R416: a hover shows the card and writes nothing. A click on the link then opens the popup.
  /// card
  run cardTest = init.then(hoverCard).then(all { assert(ui == "card" and fileFeedback == "not_checked"), leaveCard })
    .then(all { assert(ui == "reading"), hoverCard }).then(all { assert(ui == "card"), openPopup })
    .then(all { assert(ui == "popup"), unchanged })
}
