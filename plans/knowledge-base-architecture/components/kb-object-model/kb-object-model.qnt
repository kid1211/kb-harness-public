// kb-object-model: the KB as typed data objects, like classes in an OOP
// graph, and the check of one domain against the Types table of its CLAUDE.md.
//
// Module kbObjectData is the data object, a configuration model: a type with
// its fields, kinds and areas, the type it extends (is a), the types it is
// made of, with the values each part adds, and the types it links to. Then
// the breaks one object can have against its type. It is built first (R4).
//
// Module kbTypeCheck is one run of kb-types.py on one domain, a transition
// model of the graph in architecture.md. What the domain holds (a table, a
// bad row, pages that break) is chosen at init, so every mix is explored.
//
// A page that matches no collection is untyped. It is listed, and it is not
// a break: some pages have frontmatter and some do not (the user, 2026-11-20).
//
// Not modelled: how a Markdown table and frontmatter are parsed, the text of
// each break line, one line per page (the model keeps one flag per kind of
// break), and the layout of the drawn graph.

module kbObjectData {
  type Field = { name: str, kind: str, required: bool }
  type ObjType = { name: str, extends: str, fields: Set[Field], areas: Set[str], madeOf: Set[str],
    partFields: Set[Field], linksTo: Set[str] }
  // values: (field name, kind of the value found).
  // parts: (part id, its type). partVals: (part id, field name, kind of the value found).
  // links: (object id, its type). A field of kind link:<type> adds its target here too.
  type Obj = { id: str, typ: str, area: str, values: Set[(str, str)], parts: Set[(str, str)],
    partVals: Set[(str, str, str)], links: Set[(str, str)] }

  pure val KINDS = Set("text", "number", "score", "date", "list", "link")
  pure val AREAS = Set("source", "staging", "consolidated")

  // A small food world: an item, a version of a meal, and a meal that is a version.
  pure val ITEM: ObjType = { name: "item", extends: "", fields: Set({ name: "fresh_days", kind: "number", required: true }),
    areas: Set("consolidated"), madeOf: Set(), partFields: Set(), linksTo: Set() }
  pure val VERSION: ObjType = { name: "version", extends: "", fields: Set({ name: "fullness", kind: "score", required: true },
    { name: "notes", kind: "text", required: false }), areas: Set("staging"),
    madeOf: Set("item"), partFields: Set({ name: "grams", kind: "number", required: true }), linksTo: Set() }
  pure val MEAL: ObjType = { name: "meal", extends: "version", fields: Set({ name: "like", kind: "text", required: false }),
    areas: Set("consolidated"), madeOf: Set("item", "meal"), partFields: Set({ name: "grams", kind: "number", required: true }),
    linksTo: Set("version") }
  pure def typeOf(n: str): ObjType = if (n == "item") ITEM else if (n == "version") VERSION else MEAL

  /// R13: a type has its own fields and the fields of each type it extends
  pure def allFields(t: ObjType): Set[Field] =
    if (t.extends == "") t.fields
    else if (typeOf(t.extends).extends == "") t.fields.union(typeOf(t.extends).fields)
    else t.fields.union(typeOf(t.extends).fields).union(typeOf(typeOf(t.extends).extends).fields)

  /// R2: each required field the object lacks
  pure def missing(t: ObjType, o: Obj): Set[str] =
    allFields(t).filter(f => f.required and not(o.values.exists(v => v._1 == f.name))).map(f => f.name)

  /// R2: each field whose value has another kind than its type says
  pure def wrongKind(t: ObjType, o: Obj): Set[str] =
    o.values.filter(v => allFields(t).exists(f => f.name == v._1 and f.kind != v._2)).map(v => v._1)

  /// R3: the area of the name must be one the type allows
  pure def areaOk(t: ObjType, o: Obj): bool = t.areas.contains(o.area)

  /// R5: each part that lacks a required part value, or has one of the wrong kind
  pure def badPartVals(t: ObjType, o: Obj): Set[str] =
    o.parts.filter(p => t.partFields.exists(f =>
      (f.required and not(o.partVals.exists(v => v._1 == p._1 and v._2 == f.name)))
      or o.partVals.exists(v => v._1 == p._1 and v._2 == f.name and v._3 != f.kind))).map(p => p._1)

  /// R5, R6: each part or link must name an object that exists, of a type the type allows
  pure def lostLinks(t: ObjType, o: Obj, ids: Set[(str, str)]): Set[str] =
    o.parts.filter(p => not(t.madeOf.contains(p._2)) or not(ids.contains(p))).map(p => p._1)
      .union(o.links.filter(l => not(t.linksTo.contains(l._2)) or not(ids.contains(l))).map(l => l._1))

  /// R7: the ids reachable through made-of, in up to n steps
  pure def reach(objs: Set[Obj], start: str, n: int): Set[str] =
    1.to(n).fold(Set(start), (acc, _) =>
      acc.union(objs.filter(o => acc.contains(o.id)).map(o => o.parts.map(p => p._1)).flatten()))

  /// R7: an object is part of itself, directly or through other wholes
  pure def inCycle(objs: Set[Obj], o: Obj): bool =
    o.parts.exists(p => reach(objs, p._1, objs.size()).contains(o.id))

  /// R1, R2, R3: the object fits its type: its own fields and its area
  pure def fits(t: ObjType, o: Obj): bool =
    missing(t, o) == Set() and wrongKind(t, o) == Set() and areaOk(t, o)

  pure def ids(os: Set[Obj]): Set[(str, str)] = os.map(o => (o.id, o.typ))

  var objs: Set[Obj]

  action init = {
    nondet itemArea = AREAS.oneOf()
    nondet itemVals = Set(Set(), Set(("fresh_days", "number")), Set(("fresh_days", "text"))).oneOf()
    nondet mealParts = Set(Set(("i1", "item")), Set(("i1", "item"), ("m1", "meal")), Set(("x9", "item"))).oneOf()
    nondet mealVals = Set(Set(("fullness", "score")), Set(), Set(("fullness", "text")), Set(("fullness", "score"), ("like", "text"))).oneOf()
    nondet grams = Set(Set(), Set(("i1", "grams", "number")), Set(("i1", "grams", "text"))).oneOf()
    objs' = Set(
      { id: "i1", typ: "item", area: itemArea, values: itemVals, parts: Set(), partVals: Set(), links: Set() },
      { id: "m1", typ: "meal", area: "consolidated", values: mealVals, parts: mealParts, partVals: grams, links: Set() })
  }
  action step = objs' = objs

  /// R2: an object that fits has a value of the right kind for each required field, its inherited ones too
  val fitHasEachRequired = objs.forall(o => fits(typeOf(o.typ), o) implies
    allFields(typeOf(o.typ)).forall(f => not(f.required) or o.values.contains((f.name, f.kind))))
  /// R13: a meal misses fullness, which it gets from version, when the value is not there
  val inheritedFieldRequired = objs.forall(o => (o.typ == "meal" and not(o.values.exists(v => v._1 == "fullness")))
    implies missing(MEAL, o).contains("fullness"))
  /// R5: a part that names no object is lost
  val lostPartFound = objs.forall(o => o.parts.exists(p => not(ids(objs).contains(p))) implies
    lostLinks(typeOf(o.typ), o, ids(objs)) != Set())
  /// R7: a meal made of itself is in a cycle
  val selfPartIsCycle = objs.forall(o => o.parts.exists(p => p._1 == o.id) implies inCycle(objs, o))
  /// NEGATIVE CONTROL: some world has an item with no fresh_days
  val neverMissing = objs.forall(o => missing(typeOf(o.typ), o) == Set())

  /// R2: a version with no fullness misses it
  run missingScoreTest = init.then(objs' = Set({ id: "v1", typ: "version", area: "staging",
    values: Set(), parts: Set(), partVals: Set(), links: Set() })).expect(objs.forall(o => missing(VERSION, o) == Set("fullness")))
  /// R2: a score given as text is the wrong kind
  run wrongKindTest = init.then(objs' = Set({ id: "v1", typ: "version", area: "staging",
    values: Set(("fullness", "text")), parts: Set(), partVals: Set(), links: Set() })).expect(objs.forall(o => wrongKind(VERSION, o) == Set("fullness")))
  /// R3: an item in staging breaks, since its type allows consolidated only
  run areaTest = init.then(objs' = Set({ id: "i1", typ: "item", area: "staging",
    values: Set(("fresh_days", "number")), parts: Set(), partVals: Set(), links: Set() })).expect(objs.forall(o => not(fits(ITEM, o))))
  /// R1, R2, R3: an item with its field and area fits
  run fitsTest = init.then(objs' = Set({ id: "i1", typ: "item", area: "consolidated",
    values: Set(("fresh_days", "number")), parts: Set(), partVals: Set(), links: Set() })).expect(objs.forall(o => fits(ITEM, o)))
  /// R13: a meal with no fullness misses it, through version
  run inheritTest = init.then(objs' = Set({ id: "m1", typ: "meal", area: "consolidated",
    values: Set(("like", "text")), parts: Set(), partVals: Set(), links: Set() })).expect(objs.forall(o => missing(MEAL, o) == Set("fullness")))
  /// R5: a part with no grams breaks
  run partValTest = init.then(objs' = Set({ id: "m1", typ: "meal", area: "consolidated",
    values: Set(("fullness", "score")), parts: Set(("i1", "item")), partVals: Set(), links: Set() }))
    .expect(objs.forall(o => badPartVals(MEAL, o) == Set("i1")))
  /// R7: two meals made of each other are a cycle
  run cycleTest = init.then(objs' = Set(
    { id: "m1", typ: "meal", area: "consolidated", values: Set(("fullness", "score")), parts: Set(("m2", "meal")), partVals: Set(("m2", "grams", "number")), links: Set() },
    { id: "m2", typ: "meal", area: "consolidated", values: Set(("fullness", "score")), parts: Set(("m1", "meal")), partVals: Set(("m1", "grams", "number")), links: Set() }))
    .expect(objs.forall(o => inCycle(objs, o)))
  /// R7: a meal made of an item, with no loop, is no cycle
  run noCycleTest = init.then(objs' = Set(
    { id: "m1", typ: "meal", area: "consolidated", values: Set(("fullness", "score")), parts: Set(("i1", "item")), partVals: Set(("i1", "grams", "number")), links: Set() },
    { id: "i1", typ: "item", area: "consolidated", values: Set(("fresh_days", "number")), parts: Set(), partVals: Set(), links: Set() }))
    .expect(objs.forall(o => not(inCycle(objs, o))))
}

module kbTypeCheck {
  var phase: str
  var hasTable: bool   // the domain's CLAUDE.md holds a Types table
  var tableOk: bool    // each row parses, with known kinds, and names only types of the table
  var wantDraw: bool   // the caller asked for the picture, not the check
  var wantMap: bool    // the caller asked for the map of every KB
  var typedPages: bool // some page of the domain says its type: in its frontmatter
  var untyped: bool    // some page matches no collection: listed, not a break
  var fieldsOk: bool   // each typed object has its fields, of the right kind
  var areaOk: bool     // each typed object has an area its type allows
  var linksOk: bool    // each part, its values, and each link find their object
  var acyclic: bool    // no whole is part of itself
  var breaks: Set[str]
  var listed: bool     // the untyped pages were listed
  var exitCode: int

  pure def found(f: bool, a: bool, l: bool, y: bool): Set[str] =
    Set(("field", f), ("area", a), ("link", l), ("cycle", y)).filter(p => not(p._2)).map(p => p._1)

  action init = {
    nondet h = Set(true, false).oneOf()
    nondet t = Set(true, false).oneOf()
    nondet w = Set(true, false).oneOf()
    nondet m = Set(true, false).oneOf()
    nondet tp = Set(true, false).oneOf()
    nondet u = Set(true, false).oneOf()
    nondet f = Set(true, false).oneOf()
    nondet a = Set(true, false).oneOf()
    nondet l = Set(true, false).oneOf()
    nondet y = Set(true, false).oneOf()
    all { phase' = "start", hasTable' = h, tableOk' = t, wantDraw' = w, wantMap' = m, typedPages' = tp, untyped' = u, fieldsOk' = f,
      areaOk' = a, linksOk' = l, acyclic' = y, breaks' = Set(), listed' = false, exitCode' = -1 }
  }

  action keep = all { hasTable' = hasTable, tableOk' = tableOk, wantDraw' = wantDraw, wantMap' = wantMap, typedPages' = typedPages, untyped' = untyped,
    fieldsOk' = fieldsOk, areaOk' = areaOk, linksOk' = linksOk, acyclic' = acyclic }
  action same = all { breaks' = breaks, listed' = listed, exitCode' = exitCode, keep }

  /// R20: a draw of a domain whose pages say their type, with no wrong table
  def pagesDraw: bool = wantDraw and typedPages and (not(hasTable) or tableOk)
  /// R20: a draw reads the types from the pages
  action toDrawnFromPages = all { phase == "start", not(wantMap), pagesDraw, phase' = "drawn", breaks' = Set(), listed' = false, exitCode' = 0, keep }
  /// R8: a domain with a Types table is read
  action toReading = all { phase == "start", not(wantMap), not(pagesDraw), hasTable, phase' = "reading", same }
  /// R8: a domain with no Types table is not checked
  action toSkipped = all { phase == "start", not(wantMap), not(pagesDraw), not(hasTable), phase' = "skipped", breaks' = Set(), listed' = false, exitCode' = 0, keep }
  /// R8: a wrong table stops the check, exit 2
  action toBadTable = all { phase == "reading", not(tableOk), phase' = "bad_table", breaks' = Set(), listed' = false, exitCode' = 2, keep }
  /// R9: a good table and a check: each page is matched and tested
  action toMatching = all { phase == "reading", tableOk, not(wantDraw), phase' = "matching", same }
  /// R10: a good table and a draw: the graph block is written
  action toDrawing = all { phase == "reading", tableOk, wantDraw, phase' = "drawing", same }
  /// R1, R9: untyped pages are listed. One break per kind found, exit 1, or ok, exit 0
  action toEnd = all { phase == "matching",
    val b = found(fieldsOk, areaOk, linksOk, acyclic)
    all { breaks' = b, listed' = untyped, phase' = if (b == Set()) "clean" else "broken", exitCode' = if (b == Set()) 0 else 1 }, keep }
  /// R10: the graph block is printed
  action toDrawn = all { phase == "drawing", phase' = "drawn", breaks' = breaks, listed' = listed, exitCode' = 0, keep }
  /// R14: a map run reads every KB of the roots list and writes a page for each
  action toMapped = all { phase == "start", wantMap, phase' = "mapped", breaks' = Set(), listed' = false, exitCode' = 0, keep }
  /// R9: a finished run stays where it ended
  action stay = all { Set("clean", "broken", "skipped", "bad_table", "drawn", "mapped").contains(phase), phase' = phase, same }

  action step = any { toDrawnFromPages, toMapped, toReading, toSkipped, toBadTable, toMatching, toDrawing, toEnd, toDrawn, stay }

  /// R9: clean only when every typed page fits
  val cleanOnlyIfAllFit = phase == "clean" implies (fieldsOk and areaOk and linksOk and acyclic and exitCode == 0)
  /// R9: broken names each kind of break, and only those
  val brokenNamesEach = phase == "broken" implies (breaks == found(fieldsOk, areaOk, linksOk, acyclic) and breaks != Set() and exitCode == 1)
  /// R1: an untyped page is listed and never a break
  val untypedNotABreak = Set("clean", "broken").contains(phase) implies (listed == untyped and not(breaks.contains("no_collection")))
  /// R8: skipped only without a table
  val skippedOnlyWithoutTable = phase == "skipped" implies not(hasTable)
  /// R8: a bad table exits 2 and checks no page
  val badTableStops = phase == "bad_table" implies (not(tableOk) and exitCode == 2 and breaks == Set())
  /// R10: a picture only from a good table
  val drawnOnlyFromTable = phase == "drawn" implies (wantDraw and (typedPages or (hasTable and tableOk)))
  /// R14: a map only when asked, and it checks no page
  val mappedOnlyWhenAsked = phase == "mapped" implies (wantMap and breaks == Set() and exitCode == 0)
  /// NEGATIVE CONTROL: some domain breaks
  val neverBroken = phase != "broken"

  /// R8, R9, R10: a run starts on a domain with the given facts
  action startAs(h: bool, t: bool, w: bool, u: bool, f: bool, a: bool, l: bool, y: bool): bool = all {
    phase' = "start", hasTable' = h, tableOk' = t, wantDraw' = w, wantMap' = false, typedPages' = false, untyped' = u, fieldsOk' = f,
    areaOk' = a, linksOk' = l, acyclic' = y, breaks' = Set(), listed' = false, exitCode' = -1 }

  /// R12: the run ends in clean
  /// R12: the food domain today has no typed page yet, so its pages are listed as untyped and it is clean
  /// clean
  run cleanTest = startAs(true, true, false, true, true, true, true, true)
    .then(toReading).then(toMatching).then(toEnd).expect(phase == "clean" and exitCode == 0 and listed)
  /// R12: the run ends in broken
  /// R12: after the move, an item with no fresh_days breaks
  /// broken
  run brokenTest = startAs(true, true, false, false, false, true, true, true)
    .then(toReading).then(toMatching).then(toEnd).expect(phase == "broken" and breaks == Set("field"))
  /// R8: the run ends in skipped
  /// skipped
  run skippedTest = startAs(false, true, false, false, true, true, true, true)
    .then(toSkipped).expect(phase == "skipped" and exitCode == 0)
  /// R8: the run ends in bad_table
  /// bad_table
  run badTableTest = startAs(true, false, false, false, true, true, true, true)
    .then(toReading).then(toBadTable).expect(phase == "bad_table" and exitCode == 2)
  /// R10: the run ends in drawn
  /// drawn
  run drawnTest = startAs(true, true, true, false, false, false, false, false)
    .then(toReading).then(toDrawing).then(toDrawn).expect(phase == "drawn")
  /// R20: a domain with no table and typed pages ends in drawn
  run pagesDrawnTest = all { phase' = "start", hasTable' = false, tableOk' = false, wantDraw' = true, wantMap' = false, typedPages' = true,
    untyped' = false, fieldsOk' = true, areaOk' = true, linksOk' = true, acyclic' = true, breaks' = Set(), listed' = false, exitCode' = -1 }
    .then(toDrawnFromPages).expect(phase == "drawn" and exitCode == 0)
  /// R14: the run ends in mapped
  /// mapped
  run mappedTest = all { phase' = "start", hasTable' = false, tableOk' = false, wantDraw' = false, wantMap' = true, typedPages' = false, untyped' = false,
    fieldsOk' = true, areaOk' = true, linksOk' = true, acyclic' = true, breaks' = Set(), listed' = false, exitCode' = -1 }
    .then(toMapped).expect(phase == "mapped" and exitCode == 0)
}

// Module kbMapView is the map page: a tree of nodes, the focus, and what shows.
// Levels: 0 all KBs, 1 KB, 2 domain, 3 collection, 4 field.
module kbMapView {
  // A small tree: root, two KBs, a domain, a collection, a field.
  pure val PARENT = Map("personal" -> "all", "eventPNL" -> "all", "food" -> "personal", "items" -> "food", "fresh_days" -> "items")
  pure val NODES = Set("all", "personal", "eventPNL", "food", "items", "fresh_days")
  pure def depth(n: str): int = if (n == "all") 0 else if (PARENT.get(n) == "all") 1
    else if (PARENT.get(PARENT.get(n)) == "all") 2 else if (PARENT.get(PARENT.get(PARENT.get(n))) == "all") 3 else 4
  /// R15: a is b or under b
  pure def under(a: str, b: str): bool = a == b or (a != "all" and (PARENT.get(a) == b or
    (PARENT.get(a) != "all" and (PARENT.get(PARENT.get(a)) == b or (PARENT.get(PARENT.get(a)) != "all" and PARENT.get(PARENT.get(PARENT.get(a))) == b)))))
  /// R15: the focus, its parent, and what lies up to three levels under it
  pure def shown(f: str): Set[str] = NODES.filter(n => (f != "all" and n == PARENT.get(f)) or (under(n, f) and depth(n) - depth(f) <= 3))

  var home: str
  var focus: str
  var showingAll: bool
  var visible: Set[str]

  action init = { nondet h = Set("personal", "eventPNL").oneOf()
    all { home' = h, focus' = h, showingAll' = false, visible' = shown(h) } }
  /// R15: a click on a shown node makes it the focus
  action click(n: str): bool = all { visible.contains(n), home' = home, focus' = n, showingAll' = false, visible' = shown(n) }
  /// R16: Show all shows every node of every KB
  action showAll = all { home' = home, focus' = "all", showingAll' = true, visible' = NODES }
  /// R16: Reset puts the focus back on the KB the page opened on
  action reset = all { home' = home, focus' = home, showingAll' = false, visible' = shown(home) }
  action step = any { nondet n = NODES.oneOf() click(n), showAll, reset }

  /// R15: with no Show all, nothing shows more than one level over or three under the focus
  val focusWindow = not(showingAll) implies visible.forall(n => (depth(n) >= depth(focus) - 1) and (depth(n) <= depth(focus) + 3))
  /// R16: Show all shows each node
  val showAllShowsAll = showingAll implies visible == NODES
  /// R15: the focus always shows
  val focusShows = visible.contains(focus)
  /// NEGATIVE CONTROL: the field never shows
  val fieldNeverShows = not(visible.contains("fresh_days"))

  /// R15: a click on food shows personal over it and items and fresh_days under it
  run clickTest = all { home' = "personal", focus' = "personal", showingAll' = false, visible' = shown("personal") }
    .then(click("food")).expect(visible == Set("personal", "food", "items", "fresh_days"))
  /// R16: Show all, then Reset, comes back to the home KB
  run resetTest = all { home' = "personal", focus' = "personal", showingAll' = false, visible' = shown("personal") }
    .then(showAll).expect(visible == NODES).then(reset).expect(focus == "personal" and not(showingAll))
  /// R15: at the top, no level shows over the focus
  run topTest = all { home' = "personal", focus' = "personal", showingAll' = false, visible' = shown("personal") }
    .then(click("all")).expect(focus == "all" and not(visible.contains("fresh_days")))
}

// Module kbFrontmatter is the model read from the pages alone: each page says its type,
// its parent type and its relationships in its frontmatter. No table is kept apart.
module kbFrontmatter {
  type Page = { id: str, typ: str, isA: str, keys: Set[str], partOf: Set[str], madeOf: Set[str], linksTo: Set[str] }
  type Rel = (str, str, str)

  /// R17: the fields of a type are the keys of each page of that type
  pure def typeFields(ps: Set[Page], t: str): Set[str] = ps.filter(p => p.typ == t).fold(Set(), (acc, p) => acc.union(p.keys))
  /// R17: the types are what the pages say, and a page with no type is untyped
  pure def types(ps: Set[Page]): Set[str] = ps.filter(p => p.typ != "").map(p => p.typ)
  pure def typeOf(ps: Set[Page], id: str): str = ps.filter(p => p.id == id).fold("", (acc, p) => p.typ)
  /// R18: each is_a of a page, and R19: each relationship of a page, drawn between types
  pure def rels(ps: Set[Page]): Set[Rel] = ps.filter(p => p.typ != "").fold(Set(), (acc, p) =>
    acc.union(if (p.isA != "") Set((p.typ, p.isA, "is a")) else Set())
       .union(p.partOf.map(x => (p.typ, typeOf(ps, x), "part of")))
       .union(p.madeOf.map(x => (p.typ, typeOf(ps, x), "made of")))
       .union(p.linksTo.map(x => (p.typ, typeOf(ps, x), "links to"))))

  pure val NAMES = Set("", "food", "dish", "plan")
  var pages: Set[Page]
  action init = {
    nondet t1 = NAMES.oneOf()
    nondet t2 = NAMES.oneOf()
    nondet k = Set(Set("fresh_days"), Set("fullness", "easy"), Set()).oneOf()
    pages' = Set({ id: "a", typ: t1, isA: "", keys: k, partOf: Set(), madeOf: Set("b"), linksTo: Set() },
                 { id: "b", typ: t2, isA: "", keys: Set("fresh_days"), partOf: Set(), madeOf: Set(), linksTo: Set() })
  }
  action step = pages' = pages

  /// R20: no drift, each key of a typed page is a field of its type
  val noDrift = pages.forall(p => p.typ == "" or p.keys.subseteq(typeFields(pages, p.typ)))
  /// R17: an untyped page makes no type
  val untypedMakesNoType = not(types(pages).contains(""))
  /// NEGATIVE CONTROL: no page has a type
  val neverTyped = types(pages) == Set()

  /// R19: a dish made of a food draws "made of" between the types
  run madeOfTest = all { pages' = Set(
      { id: "r", typ: "dish", isA: "", keys: Set("easy"), partOf: Set(), madeOf: Set("f"), linksTo: Set() },
      { id: "f", typ: "food", isA: "", keys: Set("fresh_days"), partOf: Set(), madeOf: Set(), linksTo: Set() }) }
    .expect(rels(pages) == Set(("dish", "food", "made of")) and typeFields(pages, "dish") == Set("easy"))
  /// R18: is_a draws "is a"
  run isATest = all { pages' = Set({ id: "m", typ: "meal", isA: "dish", keys: Set(), partOf: Set(), madeOf: Set(), linksTo: Set() }) }
    .expect(rels(pages) == Set(("meal", "dish", "is a")))
  /// R17: two pages of one type give the union of their keys
  run unionTest = all { pages' = Set(
      { id: "x", typ: "food", isA: "", keys: Set("a"), partOf: Set(), madeOf: Set(), linksTo: Set() },
      { id: "y", typ: "food", isA: "", keys: Set("b"), partOf: Set(), madeOf: Set(), linksTo: Set() },
      { id: "z", typ: "", isA: "", keys: Set("c"), partOf: Set(), madeOf: Set(), linksTo: Set() }) }
    .expect(typeFields(pages, "food") == Set("a", "b") and types(pages) == Set("food"))
}
