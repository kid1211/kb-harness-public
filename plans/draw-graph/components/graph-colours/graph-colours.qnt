// The colour lines of a graph block: one node's text and fill, one link's line and text, by palette name.
// It does not cover the layout, the drawing, or which node or link a colour line names.
module graphColours {
  /// F3, F4: the palette names. Firebrick is left out: red is for errors only.
  pure val LIGHT = Set("tan", "linen", "light-blue", "white")
  pure val LINE_ONLY = Set("slate-blue")
  pure val DARK = Set("navy", "midnight", "charcoal", "olive", "fern")
  pure val PALETTE = LIGHT.union(LINE_ONLY).union(DARK)
  pure val PARTS = Set("text", "fill", "line", "label")
  pure val NAMES = PALETTE.union(Set("firebrick", "red", "#ff0000"))

  /// F3, R3: which colours fit which part.
  pure def fits(part: str, c: str): bool =
    if (part == "fill") PALETTE.contains(c)
    else if (part == "line") LIGHT.union(LINE_ONLY).contains(c)
    else LIGHT.contains(c)

  var phase: str      // read, plain, applied, error
  var isColour: bool  // the line is a colour line
  var part: str       // text, fill (a node), line, label (a link)
  var colour: str     // the name the line gives
  var shown: str      // the colour the part shows: "kind" for the colour of its kind

  /// F5: a run starts at read, with each part in the colour of its kind.
  action initWith(cl: bool, p: str, c: str): bool =
    all { phase' = "read", isColour' = cl, part' = p, colour' = c, shown' = "kind" }
  action init = {
    nondet cl = Set(true, false).oneOf()
    nondet p = PARTS.oneOf()
    nondet c = NAMES.oneOf()
    initWith(cl, p, c)
  }

  /// F5, R5: a line that is not a colour line changes no colour.
  action plain = all { phase == "read", not(isColour), phase' = "plain",
    isColour' = isColour, part' = part, colour' = colour, shown' = shown }
  /// F1, F2, F5, R1, R2, R5: a known colour that fits its part wins over the colour of the kind.
  action apply = all { phase == "read", isColour, PALETTE.contains(colour), fits(part, colour), phase' = "applied",
    isColour' = isColour, part' = part, colour' = colour, shown' = colour }
  /// F4, R4: an unknown name, firebrick, or a dark colour on text or a line is an error.
  action refuse = all { phase == "read", isColour, not(PALETTE.contains(colour) and fits(part, colour)), phase' = "error",
    isColour' = isColour, part' = part, colour' = colour, shown' = shown }
  /// The run ends at plain, applied or error.
  action done = all { Set("plain", "applied", "error").contains(phase),
    phase' = phase, isColour' = isColour, part' = part, colour' = colour, shown' = shown }

  action step = any { plain, apply, refuse, done }

  /// F3, F4, R3: a part shows only a palette colour that fits it, or the colour of its kind.
  val shownFits = shown == "kind" or (PALETTE.contains(shown) and fits(part, shown))
  /// F4: firebrick and a name not in the palette never show.
  val noRedNoUnknown = shown != "firebrick" and (shown == "kind" or PALETTE.contains(shown))
  /// F4, R4: a colour line with a bad name ends in an error.
  val badIsError = (phase != "read" and isColour and not(PALETTE.contains(colour) and fits(part, colour))) implies phase == "error"
  /// F5, R5: a graph with no colour line keeps the colours of each kind.
  val plainKeepsKind = not(isColour) implies shown == "kind"
  /// NEGATIVE CONTROL: false on purpose, since a colour does get applied.
  val neverApplied = phase != "applied"

  /// F1: a node takes its own text colour.
  /// applied
  run nodeTextTest = initWith(true, "text", "tan").then(apply).expect(phase == "applied" and shown == "tan")
  /// F1: a node takes a dark fill.
  run nodeFillTest = initWith(true, "fill", "midnight").then(apply).expect(shown == "midnight")
  /// F2: a link takes its own line colour.
  run linkLineTest = initWith(true, "line", "slate-blue").then(apply).expect(shown == "slate-blue")
  /// F2: a link takes its own label colour.
  run linkLabelTest = initWith(true, "label", "light-blue").then(apply).expect(shown == "light-blue")
  /// F3, F4: a dark colour on text is an error.
  /// error
  run darkTextTest = initWith(true, "text", "navy").then(refuse).expect(phase == "error" and shown == "kind")
  /// F4: firebrick is an error.
  run firebrickTest = initWith(true, "fill", "firebrick").then(refuse).expect(phase == "error")
  /// F4: a hex value is an error.
  run hexTest = initWith(true, "line", "#ff0000").then(refuse).expect(phase == "error")
  /// F5: no colour line, no change.
  /// plain
  run plainTest = initWith(false, "text", "tan").then(plain).expect(phase == "plain" and shown == "kind")
}
