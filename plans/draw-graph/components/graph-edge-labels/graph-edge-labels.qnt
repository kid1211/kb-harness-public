// Where a link's text sits: on the line, in a gap the line breaks for, wrapped past a max width.
// It does not cover node text, group names, loops inside a node, or colours.
module graphEdgeLabels {
  /// F3: the max width of a link's text, in characters, about "get-grocery-list".
  pure val MAX_CHARS = 16

  var phase: str      // read, one_line, wrapped
  var chars: int      // the width of the text, in characters
  var lines: int      // the lines the text takes
  var onLine: bool    // the text's centre is on the link
  var gap: bool       // the link is hidden behind the text, in the page background
  var room: bool      // the layout got the size of the text as drawn, all lines

  /// F1: a run starts at read, with a text of 1 to 40 characters.
  action initWith(c: int): bool = all { phase' = "read", chars' = c, lines' = 0,
    onLine' = false, gap' = false, room' = false }
  action init = {
    nondet c = 1.to(40).oneOf()
    initWith(c)
  }

  /// F1, F2, F4: a text within the max width sits on one line, on the link, in a gap.
  action oneLine = all { phase == "read", chars <= MAX_CHARS, phase' = "one_line", chars' = chars,
    lines' = 1, onLine' = true, gap' = true, room' = true }
  /// F1, F2, F3, F4: a wider text wraps onto more lines, each within the max width.
  // ponytail: lines from chars alone; the code wraps by words and measured width.
  action wrap = all { phase == "read", chars > MAX_CHARS, phase' = "wrapped", chars' = chars,
    lines' = (chars + MAX_CHARS - 1) / MAX_CHARS, onLine' = true, gap' = true, room' = true }
  /// The run ends at one_line or wrapped.
  action done = all { Set("one_line", "wrapped").contains(phase),
    phase' = phase, chars' = chars, lines' = lines, onLine' = onLine, gap' = gap, room' = room }

  action step = any { oneLine, wrap, done }

  /// F1, F2, R1, R2: a drawn text sits on its link, with the link broken behind it.
  val inTheLine = phase != "read" implies (onLine and gap)
  /// F3, R3: no line of the text is wider than the max width.
  val widthCapped = phase != "read" implies lines * MAX_CHARS >= chars
  /// F3, R3: a text wraps only when it is wider than the max width.
  val wrapOnlyWhenWide = (phase == "wrapped") iff (phase != "read" and chars > MAX_CHARS)
  /// F4, R4: the layout leaves room for every line of the text.
  val roomForText = phase != "read" implies room
  /// F5: the note of a link: each `about` line whose text is the link's text, in order.
  pure def note(abouts: List[(str, str)], text: str): List[str] = abouts.select(a => a._1 == text).foldl([], (acc, a) => acc.append(a._2))
  /// F5: two about lines for one text give a note of two lines, and a link with no about line has none.
  run aboutTest = all { assert(note([("food-record-body", "1. OCR"), ("x", "y"), ("food-record-body", "2. ask")], "food-record-body") == ["1. OCR", "2. ask"]
    and note([], "a") == []), initWith(5) }
  /// NEGATIVE CONTROL: false on purpose, since a long text does wrap.
  val neverWrapped = lines <= 1

  /// F1, F2: a short text sits on one line in the gap.
  /// one_line
  run shortTextTest = initWith(5).then(oneLine).expect(phase == "one_line" and lines == 1 and onLine and gap)
  /// F3: "get-grocery-list", 16 characters, still fits one line.
  run maxWidthTest = initWith(16).then(oneLine).expect(lines == 1)
  /// F3, F4: 17 characters wrap onto 2 lines, with room for both.
  /// wrapped
  run wrapTest = initWith(17).then(wrap).expect(phase == "wrapped" and lines == 2 and room)
  /// F3: a short text cannot wrap.
  run shortNoWrapTest = initWith(16).then(wrap).fail()
}
