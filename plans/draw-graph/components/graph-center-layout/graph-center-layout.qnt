// The center layout: a graph with ring lines puts each node on a ring around a center, and a node
// with more links sits nearer the center. A graph with no ring line keeps the ELK layout.
// Not covered: the angle of each node and where each link's text sits. The graph check judges those.
// NEGATIVE CONTROL: neverBroken is false on purpose.
module graphCenterLayout {
  /// F1, F2: the gap between two rings, and the most a node's links pull it in. The pull stays under the gap.
  pure val STEP = 100
  pure val PULL = 40

  /// F1, F2: how far from the center a node sits: further for a ring further out, nearer for more links.
  pure def radius(ring: int, links: int, most: int): int = STEP * ring + PULL - (if (most == 0) 0 else PULL * links / most)

  var phase: str      // read, layered, placing, centered, broken
  var hasRings: bool  // the graph has a ring line
  var clean: bool     // the drawing passes the graph check

  action init = all { phase' = "read", nondet r = Set(true, false).oneOf() hasRings' = r, nondet c = Set(true, false).oneOf() clean' = c }
  /// F1: no ring line, the ELK layout as before.
  action toLayered = all { phase == "read", not(hasRings), phase' = "layered", hasRings' = hasRings, clean' = clean }
  /// F1, F2: ring lines, each node on its ring.
  action toPlacing = all { phase == "read", hasRings, phase' = "placing", hasRings' = hasRings, clean' = clean }
  /// F3: the check passes.
  action toCentered = all { phase == "placing", clean, phase' = "centered", hasRings' = hasRings, clean' = clean }
  /// F3: the check names each rule the drawing breaks.
  action toBroken = all { phase == "placing", not(clean), phase' = "broken", hasRings' = hasRings, clean' = clean }
  /// F1, F3: an end state stays.
  action stay = all { phase' = phase, hasRings' = hasRings, clean' = clean }
  action step = any { toLayered, toPlacing, toCentered, toBroken, stay }

  /// F1: a node of an inner ring sits nearer the center than any node of an outer ring.
  val ringsInOrder = Set(0, 1, 2, 3).forall(r => Set(0, 1, 2, 3).forall(l => Set(0, 1, 2, 3).forall(k =>
    r < 3 implies radius(r, 0, 3) < radius(r + 1, k, 3) and radius(r, l, 3) < radius(r + 1, 0, 3))))
  /// F2: inside one ring, more links, nearer the center.
  val moreLinksNearer = Set(0, 1, 2, 3).forall(a => Set(0, 1, 2, 3).forall(b => a < b implies radius(1, b, 3) <= radius(1, a, 3)))
  /// F1: a graph with no ring line is never placed on rings.
  val noRingsLayered = phase == "placing" implies hasRings
  /// F3: a centered graph passed the check.
  val centeredIsClean = phase == "centered" implies clean
  /// F4: in the center layout, the text of a link shows only on hover.
  pure def linkTextShown(rings: bool, hovered: bool): bool = not(rings) or hovered
  /// F4: a dot with more links is no smaller.
  pure def dotSize(links: int): int = 12 + 3 * links
  val dotsGrow = Set(0, 1, 2, 3).forall(a => Set(0, 1, 2, 3).forall(b => a <= b implies dotSize(a) <= dotSize(b)))
  /// NEGATIVE CONTROL: false on purpose, a run reaches broken.
  val neverBroken = phase != "broken"

  /// placing
  /// F2: the node with the most links sits on the inner edge of its ring, and one with none on the outer edge.
  run radiusTest = all { assert(radius(1, 3, 3) == STEP and radius(1, 0, 3) == STEP + PULL and radius(0, 0, 0) == PULL), init }
  /// centered
  /// F4: link text hides in the center layout until hover, and always shows in the layered one.
  run dotTest = all { assert(not(linkTextShown(true, false)) and linkTextShown(true, true) and linkTextShown(false, false) and dotSize(3) > dotSize(1)), init }
  /// F3: ring lines and a clean drawing end centered.
  run centeredTest = all { phase' = "read", hasRings' = true, clean' = true }.then(toPlacing).then(toCentered)
    .then(all { assert(phase == "centered"), stay })
  /// layered
  /// F1: no ring line, the ELK layout.
  run layeredTest = all { phase' = "read", hasRings' = false, clean' = true }.then(toLayered).then(all { assert(phase == "layered"), stay })
  /// broken
  /// F3: a drawing that breaks a rule ends broken.
  run brokenTest = all { phase' = "read", hasRings' = true, clean' = false }.then(toPlacing).then(toBroken)
    .then(all { assert(phase == "broken"), stay })
}
