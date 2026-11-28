// The word cap of a graph node name: up to 6 words, joined by _, each _ shown as a space.
// It does not cover the layout, the drawing, group names or the other line forms.
module graphNodeNames {
  /// F1, F2, R1, R2: the most words a node name may have.
  pure val MAX_WORDS = 6

  var phase: str     // read, plain, warned
  var words: int     // the words of the name, counted by its _ parts
  var warned: bool   // the parse warned about the name
  var drawn: bool    // the node is drawn

  /// F1: a run starts at read, with a name of 1 to 9 words.
  action initWith(w: int): bool = all { phase' = "read", words' = w, warned' = false, drawn' = false }
  action init = {
    nondet w = 1.to(9).oneOf()
    initWith(w)
  }

  /// F1, F3, R1, R3: a name of 6 words or fewer draws with no warning.
  action plain = all { phase == "read", words <= MAX_WORDS, phase' = "plain",
    words' = words, warned' = false, drawn' = true }
  /// F2, R2: a name of 7 words or more still draws, and the parse warns.
  action warn = all { phase == "read", words > MAX_WORDS, phase' = "warned",
    words' = words, warned' = true, drawn' = true }
  /// The run ends at plain or warned.
  action done = all { Set("plain", "warned").contains(phase),
    phase' = phase, words' = words, warned' = warned, drawn' = drawn }

  action step = any { plain, warn, done }

  /// F2, F3, R2, R3: the parse warns only for a name over the cap.
  val warnOnlyOverCap = warned iff (phase != "read" and words > MAX_WORDS)
  /// F2, R2: every node draws once read, over the cap too.
  val alwaysDrawn = phase != "read" implies drawn
  /// F1, F3, R1, R3: a name within the cap ends plain.
  val withinCapIsPlain = (phase != "read" and words <= MAX_WORDS) implies phase == "plain"
  /// NEGATIVE CONTROL: false on purpose, since a long name does warn.
  val neverWarned = not(warned)

  /// F1, R1: one word draws plain.
  /// plain
  run oneWordTest = initWith(1).then(plain).expect(phase == "plain" and not(warned) and drawn)
  /// F1, F3, R1, R3: six words draw plain.
  run sixWordsTest = initWith(6).then(plain).expect(phase == "plain" and not(warned))
  /// F2, R2: seven words draw, with a warning.
  /// warned
  run sevenWordsTest = initWith(7).then(warn).expect(phase == "warned" and warned and drawn)
  /// F2, R2: six words cannot warn.
  run sixWordsNoWarnTest = initWith(6).then(warn).fail()
}
