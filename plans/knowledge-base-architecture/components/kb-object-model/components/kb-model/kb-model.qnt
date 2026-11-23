// The KB model: the rules every KB model imports, and the run of the script
// `kb-model.py`. The rules module is the design of `.claude/lib/kb-model/kb-model-rules.qnt`.
// The run module is the graph of architecture.md.
//
// Not covered: the public mark (R4 waits), how the script parses a page, and the JSON of R18
// beyond "the types of the model".

module kbModelRules {
  // NEGATIVE CONTROL: this module has no state, so quint run cannot run it.
  // Its negative control is noDriftNegative of kbModelRuleCases, which runs these rules.

  type Area = Source | Staging | Consolidated
  type Kind = Text | Number | Score | Day | ListOf
  type Field = { name: str, kind: Kind, required: bool, public: bool }
  /// R19, R13: a type is a value: its areas, parent, fields, relationships and part value fields.
  type ObjType = { areas: Set[Area], parent: str, fields: Set[Field], madeOf: Set[str], partOf: Set[str],
                   linksTo: Set[str], partFields: Set[Field], cites: Set[str] }
  /// R21: a part names a path and the values it adds, such as grams.
  type Part = { path: str, values: str -> Kind }
  // typ "" is untyped. keys: each field with the kind of its value.
  type File = { path: str, area: Area, typ: str, keys: str -> Kind, parts: Set[Part], partOf: Set[str],
                linksTo: Set[str], cites: Set[str] }
  type Break = { path: str, why: str, about: str }
  /// R5: a source file gets its type by a file pattern, which the script matches.
  type Pattern = { typ: str, glob: str }

  pure def has(m: str -> ObjType, t: str): bool = m.keys().contains(t)
  pure def parentOf(m: str -> ObjType, t: str): str = if (has(m, t)) m.get(t).parent else ""

  /// R19, R21: t and each type over it, followed as deep as the count of types.
  pure def lineage(m: str -> ObjType, t: str): Set[str] =
    range(0, m.keys().size() + 1).foldl(Set(t), (acc, i) => acc.union(acc.map(x => parentOf(m, x)).filter(x => x != "")))
  pure def isA(m: str -> ObjType, t: str, w: str): bool = lineage(m, t).contains(w)
  pure def fitsAny(m: str -> ObjType, t: str, ws: Set[str]): bool = ws.exists(w => isA(m, t, w))
  /// R19: the fields of t and of each type over it. A field that a lower type declares again wins.
  pure def allFields(m: str -> ObjType, t: str): Set[Field] = {
    val up = lineage(m, t).filter(x => has(m, x))
    up.fold(Set(), (acc, x) => acc.union(m.get(x).fields.filter(fl =>
      not(up.exists(y => y != x and isA(m, y, x) and m.get(y).fields.exists(g => g.name == fl.name))))))
  }

  pure def at(files: Set[File], p: str): Set[File] = files.filter(g => g.path == p)
  pure def typeAt(files: Set[File], p: str): str = at(files, p).fold("", (acc, g) => g.typ)
  pure def isFile(files: Set[File], p: str): bool = at(files, p).size() > 0
  pure def partPaths(f: File): Set[str] = f.parts.map(x => x.path)
  pure def outLinks(f: File): Set[str] = partPaths(f).union(f.partOf).union(f.linksTo).union(f.cites)

  /// R21: the parts of a file, by its own part lines and by each file that says it is part of it.
  pure def children(files: Set[File], f: File): Set[str] =
    partPaths(f).union(files.filter(h => h.partOf.contains(f.path)).map(h => h.path))
  /// R21: the files a path reaches by its parts, as deep as the count of files.
  pure def partReach(files: Set[File], f: File): Set[str] =
    range(0, files.size() + 1).foldl(children(files, f), (acc, i) =>
      acc.union(files.filter(g => acc.contains(g.path)).fold(Set(), (a, g) => a.union(children(files, g)))))
  /// R16: the files a file reaches by any link.
  pure def linkReach(files: Set[File], f: File): Set[str] =
    range(0, files.size() + 1).foldl(outLinks(f), (acc, i) =>
      acc.union(files.filter(g => acc.contains(g.path)).fold(Set(), (a, g) => a.union(outLinks(g)))))

  /// R13, R21: the breaks of the model itself, from each part of a type.
  pure def modelBreaks(m: str -> ObjType): Set[Break] =
    m.keys().fold(Set(), (acc, t) => {
      val o = m.get(t)
      val refs = Set(o.parent).filter(x => x != "").union(o.madeOf).union(o.partOf).union(o.linksTo).union(o.cites)
      val undefined = refs.filter(r => not(has(m, r))).map(r => { path: t, why: "no such type", about: r })
      val cycle = if (o.parent != "" and isA(m, o.parent, t)) Set({ path: t, why: "is_a cycle", about: o.parent }) else Set()
      acc.union(undefined).union(cycle)
    })

  /// R21, R16: the breaks of one file. An untyped file has none.
  pure def fileBreaks(m: str -> ObjType, files: Set[File], f: File): Set[Break] =
    if (f.typ == "") Set()
    else if (not(has(m, f.typ))) Set({ path: f.path, why: "unknown type", about: f.typ })
    else {
      val o = m.get(f.typ)
      val fs = allFields(m, f.typ)
      val names = fs.map(x => x.name)
      val area = if (o.areas.contains(f.area)) Set() else Set({ path: f.path, why: "wrong area", about: f.typ })
      val extra = f.keys.keys().exclude(names).map(k => { path: f.path, why: "extra field", about: k })
      val missing = fs.filter(x => x.required and not(f.keys.keys().contains(x.name))).map(x => { path: f.path, why: "missing field", about: x.name })
      val kind = fs.filter(x => x.kind != Text and f.keys.keys().contains(x.name) and f.keys.get(x.name) != x.kind).map(x => { path: f.path, why: "wrong kind", about: x.name })
      val gone = outLinks(f).filter(p => not(isFile(files, p))).map(p => { path: f.path, why: "link to no file", about: p })
      def live(p: str): bool = isFile(files, p) and typeAt(files, p) != ""
      val part = partPaths(f).filter(p => isFile(files, p) and not(fitsAny(m, typeAt(files, p), o.madeOf))).map(p => { path: f.path, why: "wrong part", about: p })
      val pval = f.parts.fold(Set(), (acc, x) => acc.union(
                   x.values.keys().filter(k => not(o.partFields.exists(pf => pf.name == k and (pf.kind == Text or pf.kind == x.values.get(k)))))
                    .map(k => { path: f.path, why: "wrong part value", about: k })
                   .union(o.partFields.filter(pf => pf.required and not(x.values.keys().contains(pf.name)))
                    .map(pf => { path: f.path, why: "missing part value", about: pf.name }))))
      val whole = f.partOf.filter(p => isFile(files, p) and not(fitsAny(m, typeAt(files, p), o.partOf))).map(p => { path: f.path, why: "wrong whole", about: p })
      val link = f.linksTo.filter(p => isFile(files, p) and not(fitsAny(m, typeAt(files, p), o.linksTo))).map(p => { path: f.path, why: "wrong link", about: p })
      val cite = f.cites.filter(p => live(p) and not(fitsAny(m, typeAt(files, p), o.cites))).map(p => { path: f.path, why: "wrong citation", about: p })
      val loop = if (partReach(files, f).contains(f.path)) Set({ path: f.path, why: "part of itself", about: f.path }) else Set()
      val reach = linkReach(files, f)
      val reached = files.filter(g => reach.contains(g.path) and g.area == Source).size() > 0
      val alone = if (f.area != Source and not(reached)) Set({ path: f.path, why: "reaches no source", about: f.path }) else Set()
      area.union(extra).union(missing).union(kind).union(gone).union(part).union(pval).union(whole).union(link).union(cite).union(loop).union(alone)
    }

  /// R21: every break of every file.
  pure def drift(m: str -> ObjType, files: Set[File]): Set[Break] =
    files.fold(Set(), (acc, f) => acc.union(fileBreaks(m, files, f)))
  /// R21: the breaks of the files and of the model, which the KB check module runs.
  pure def allBreaks(m: str -> ObjType, files: Set[File]): Set[Break] = drift(m, files).union(modelBreaks(m))
  /// R5: the untyped files, listed apart.
  pure def untyped(files: Set[File]): Set[str] = files.filter(f => f.typ == "").map(f => f.path)
}

// One bad file per rule, so each rule is seen to fire.
module kbModelRuleCases {
  import kbModelRules.*

  pure val none: Set[Field] = Set()
  pure def t(areas: Set[Area], parent: str, fs: Set[Field], madeOf: Set[str], cites: Set[str]): ObjType =
    { areas: areas, parent: parent, fields: fs, madeOf: madeOf, partOf: Set(), linksTo: Set(), partFields: Set({ name: "grams", kind: Number, required: false, public: true }), cites: cites }
  pure val m: str -> ObjType = Map(
    "note" -> t(Set(Source), "", none, Set(), Set()),
    "item" -> t(Set(Consolidated), "", Set({ name: "source", kind: Text, required: true, public: true }), Set(), Set("note")),
    "food" -> t(Set(Consolidated), "item", Set({ name: "shelf_life", kind: Number, required: false, public: true }), Set(), Set("note")),
    "dish" -> t(Set(Consolidated, Staging), "item", none, Set("food", "dish"), Set("note")).with("partOf", Set("dish")),
    "bowl" -> t(Set(Consolidated), "item", Set({ name: "source", kind: Number, required: true, public: true }), Set("food"), Set("note"))
                .with("partFields", Set({ name: "note", kind: Text, required: false, public: true })),
    "meal" -> t(Set(Consolidated), "", Set({ name: "day", kind: Day, required: true, public: true }), Set("dish"), Set("note"))
                .with("linksTo", Set("dish"))
                .with("partFields", Set({ name: "servings", kind: Number, required: true, public: true })),
  )
  pure def f(path: str, area: Area, typ: str, ks: str -> Kind, parts: Set[Part], cites: Set[str]): File =
    { path: path, area: area, typ: typ, keys: ks, parts: parts, partOf: Set(), linksTo: Set(), cites: cites }
  pure val src: str -> Kind = Map("source" -> Text)
  pure val good: Set[File] = Set(
    f("n.source.md", Source, "note", Map(), Set(), Set()),
    f("photo.source.jpeg", Source, "", Map(), Set(), Set()),
    f("rice.md", Consolidated, "food", Map("source" -> Text, "shelf_life" -> Number), Set(), Set("n.source.md")),
    f("congee.md", Consolidated, "dish", src, Set({ path: "rice.md", values: Map("grams" -> Number) }), Set("photo.source.jpeg")),
    f("loose.md", Consolidated, "", Map("x" -> Text), Set(), Set()),
    f("t.md", Consolidated, "food", Map("source" -> Number), Set(), Set("n.source.md")),
    f("bw.md", Consolidated, "bowl", Map("source" -> Number), Set({ path: "rice.md", values: Map("note" -> Number) }), Set("n.source.md")),
    f("m0.md", Consolidated, "meal", Map("day" -> Day), Set({ path: "congee.md", values: Map("servings" -> Number) }), Set("n.source.md"))
      .with("linksTo", Set("congee.md")),
  )
  pure val bad: Set[File] = good.union(Set(
    f("a.md", Staging, "food", src, Set(), Set("n.source.md")),
    f("b.md", Consolidated, "food", Map("source" -> Text, "spicy" -> Text), Set(), Set("n.source.md")),
    f("c.md", Consolidated, "food", Map(), Set(), Set("n.source.md")),
    f("d.md", Consolidated, "food", Map("source" -> Text, "shelf_life" -> Text), Set(), Set("n.source.md")),
    f("e.md", Consolidated, "dish", src, Set({ path: "n.source.md", values: Map() }), Set("n.source.md")),
    f("f.md", Consolidated, "dish", src, Set({ path: "rice.md", values: Map("cups" -> Number) }), Set("n.source.md")),
    f("g.md", Consolidated, "soup", Map(), Set(), Set()),
    f("h.md", Consolidated, "food", src, Set(), Set("gone.md", "n.source.md")),
    f("i.md", Consolidated, "food", src, Set(), Set()),
    f("j.md", Consolidated, "dish", src, Set({ path: "k.md", values: Map() }), Set("n.source.md")),
    f("k.md", Consolidated, "dish", src, Set({ path: "j.md", values: Map() }), Set("n.source.md")),
    f("l.md", Consolidated, "food", src, Set(), Set("rice.md")),
    f("m1.md", Consolidated, "meal", Map("day" -> Day), Set({ path: "congee.md", values: Map("servings" -> Number) }), Set("n.source.md"))
      .with("linksTo", Set("rice.md")),
    f("m2.md", Consolidated, "meal", Map("day" -> Text), Set({ path: "congee.md", values: Map() }), Set("n.source.md")),
    f("p.md", Consolidated, "food", src, Set(), Set("n.source.md")).with("partOf", Set("n.source.md")),
    f("q1.md", Consolidated, "dish", src, Set(), Set("n.source.md")).with("partOf", Set("q2.md")),
    f("q2.md", Consolidated, "dish", src, Set(), Set("n.source.md")).with("partOf", Set("q1.md")),
    f("r.md", Consolidated, "dish", src, Set({ path: "photo.source.jpeg", values: Map() }), Set("n.source.md")),
    f("bx.md", Consolidated, "bowl", src, Set(), Set("n.source.md")),
  ))
  /// R21: note is_a food is_a item is_a note, and note names a type that does not exist.
  pure val cyclic: str -> ObjType = m
    .put("note", t(Set(Source), "food", none, Set("cake"), Set()))
    .put("item", t(Set(Consolidated), "note", none, Set(), Set()))

  var breaksGood: Set[Break]
  var breaksBad: Set[Break]
  action init = all { breaksGood' = allBreaks(m, good), breaksBad' = allBreaks(m, bad) }
  action step = all { breaksGood' = breaksGood, breaksBad' = breaksBad }

  /// R21: the good files hold no break.
  val noDrift = breaksGood == Set()
  /// R5: an untyped file is listed and is no break.
  val untypedNoBreak = breaksGood.forall(b => not(untyped(good).contains(b.path)))
  // NEGATIVE CONTROL: the bad files must break, so the check can fail.
  val noDriftNegative = breaksBad == Set()

  /// R21, R16: each rule fires on its own file, with its reason.
  run eachRuleFiresTest = init.then(all {
    assert(drift(m, bad) == Set(
      { path: "a.md", why: "wrong area", about: "food" },
      { path: "b.md", why: "extra field", about: "spicy" },
      { path: "c.md", why: "missing field", about: "source" },
      { path: "d.md", why: "wrong kind", about: "shelf_life" },
      { path: "e.md", why: "wrong part", about: "n.source.md" },
      { path: "f.md", why: "wrong part value", about: "cups" },
      { path: "g.md", why: "unknown type", about: "soup" },
      { path: "h.md", why: "link to no file", about: "gone.md" },
      { path: "i.md", why: "reaches no source", about: "i.md" },
      { path: "j.md", why: "part of itself", about: "j.md" },
      { path: "k.md", why: "part of itself", about: "k.md" },
      { path: "l.md", why: "wrong citation", about: "rice.md" },
      { path: "m1.md", why: "wrong link", about: "rice.md" },
      { path: "m2.md", why: "wrong kind", about: "day" },
      { path: "m2.md", why: "missing part value", about: "servings" },
      { path: "p.md", why: "wrong whole", about: "n.source.md" },
      { path: "q1.md", why: "part of itself", about: "q1.md" },
      { path: "q2.md", why: "part of itself", about: "q2.md" },
      { path: "r.md", why: "wrong part", about: "photo.source.jpeg" },
      { path: "bx.md", why: "wrong kind", about: "source" },
    )),
    assert(untyped(bad) == Set("photo.source.jpeg", "loose.md")),
    step,
  })
  /// R21: the model breaks: a name no type defines, and an is_a cycle.
  run modelBreaksTest = init.then(all {
    assert(modelBreaks(cyclic) == Set(
      { path: "note", why: "no such type", about: "cake" },
      { path: "note", why: "is_a cycle", about: "food" },
      { path: "food", why: "is_a cycle", about: "item" },
      { path: "item", why: "is_a cycle", about: "note" },
    )),
    step,
  })
}

// The run of kb-model.py, one state per state node of architecture.md.
module kbModelRun {
  // A KB as the run sees it: does it have a model, does it typecheck, how many breaks.
  type Kb = { hasModel: bool, typechecks: bool, dataOk: bool, breaks: int }
  var phase: str
  var cmd: str
  var kb: Kb
  var exitCode: int
  var modelWritten: bool

  action init = {
    nondet c = Set("check", "init", "types").oneOf()
    nondet h = Set(true, false).oneOf()
    nondet tc = Set(true, false).oneOf()
    nondet d = Set(true, false).oneOf()
    nondet b = Set(0, 1, 3).oneOf()
    all { phase' = "start", cmd' = c, kb' = { hasModel: h, typechecks: tc, dataOk: d, breaks: b }, exitCode' = -1, modelWritten' = false }
  }
  /// R17: init writes a first model only when the KB has none.
  action toFirstModel = all { phase == "start", cmd == "init", not(kb.hasModel),
    phase' = "first_model", exitCode' = 0, modelWritten' = true, cmd' = cmd, kb' = kb }
  /// R17: the script never writes a model over one that exists.
  action toHasModel = all { phase == "start", cmd == "init", kb.hasModel,
    phase' = "kept", exitCode' = 0, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21: check and types need a model.
  action toNoModel = all { phase == "start", cmd != "init", not(kb.hasModel),
    phase' = "no_model", exitCode' = 2, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21: a model that does not typecheck exits 2.
  action toBadModel = all { phase == "start", cmd != "init", kb.hasModel, not(kb.typechecks),
    phase' = "bad_model", exitCode' = 2, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21: the script writes the files as Quint data and runs the rules.
  action toChecking = all { phase == "start", cmd == "check", kb.hasModel, kb.typechecks,
    phase' = "checking", exitCode' = -1, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21: the file data fails in Quint, so the check ends as a bad model.
  action toBadData = all { phase == "checking", not(kb.dataOk),
    phase' = "bad_model", exitCode' = 2, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21: one line per break, exit 1.
  action toDrifted = all { phase == "checking", kb.dataOk, kb.breaks > 0,
    phase' = "drifted", exitCode' = 1, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21, R5: no break: the untyped files listed, exit 0.
  action toClean = all { phase == "checking", kb.dataOk, kb.breaks == 0,
    phase' = "clean", exitCode' = 0, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R18: the types of the model as JSON, for kb-types.py.
  action toExported = all { phase == "start", cmd == "types", kb.hasModel, kb.typechecks,
    phase' = "exported", exitCode' = 0, modelWritten' = false, cmd' = cmd, kb' = kb }
  /// R21: an end state stays as it is.
  action stay = all { phase' = phase, cmd' = cmd, kb' = kb, exitCode' = exitCode, modelWritten' = modelWritten }

  action step = any { toFirstModel, toHasModel, toNoModel, toBadModel, toChecking, toBadData, toDrifted, toClean, toExported, stay }

  /// R21: each end state has its exit code.
  val exitFits =
    (phase == "clean" implies exitCode == 0) and (phase == "drifted" implies exitCode == 1)
    and ((phase == "bad_model" or phase == "no_model") implies exitCode == 2)
    and ((phase == "first_model" or phase == "kept" or phase == "exported") implies exitCode == 0)
  /// R21: clean means no break, drifted means at least one.
  val breaksFit = (phase == "clean" implies kb.breaks == 0) and (phase == "drifted" implies kb.breaks > 0)
  /// R17: a model is written only for a KB with none.
  val neverOverwrite = modelWritten implies not(kb.hasModel)
  /// R18: the types are printed only from a model that typechecks.
  val exportNeedsModel = phase == "exported" implies (kb.hasModel and kb.typechecks)
  // NEGATIVE CONTROL: some run ends drifted, so this must fail.
  val neverDrifted = phase != "drifted"

  /// R21: the run that ends at clean.
  /// clean
  run cleanTest = init.then(all { phase' = "start", cmd' = "check", kb' = { hasModel: true, typechecks: true, dataOk: true, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toChecking).then(toClean).then(all { assert(exitCode == 0), stay })
  /// R21: the run that ends at drifted.
  /// drifted
  run driftedTest = init.then(all { phase' = "start", cmd' = "check", kb' = { hasModel: true, typechecks: true, dataOk: true, breaks: 3 }, exitCode' = -1, modelWritten' = false })
    .then(toChecking).then(toDrifted).then(all { assert(exitCode == 1), stay })
  /// R21: file data that fails in Quint ends at bad_model too.
  run badDataTest = init.then(all { phase' = "start", cmd' = "check", kb' = { hasModel: true, typechecks: true, dataOk: false, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toChecking).then(toBadData).then(all { assert(exitCode == 2), stay })
  /// R21: the run that ends at bad_model.
  /// bad_model
  run badModelTest = init.then(all { phase' = "start", cmd' = "check", kb' = { hasModel: true, typechecks: false, dataOk: true, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toBadModel).then(all { assert(exitCode == 2), stay })
  /// R21: the run that ends at no_model.
  /// no_model
  run noModelTest = init.then(all { phase' = "start", cmd' = "types", kb' = { hasModel: false, typechecks: false, dataOk: true, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toNoModel).then(all { assert(exitCode == 2), stay })
  /// R17: the run that ends at first_model.
  /// first_model
  run firstModelTest = init.then(all { phase' = "start", cmd' = "init", kb' = { hasModel: false, typechecks: false, dataOk: true, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toFirstModel).then(all { assert(modelWritten), stay })
  /// R17: the run that ends at kept.
  /// kept
  run keptTest = init.then(all { phase' = "start", cmd' = "init", kb' = { hasModel: true, typechecks: true, dataOk: true, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toHasModel).then(all { assert(not(modelWritten)), stay })
  /// R18: the run that ends at exported.
  /// exported
  run exportedTest = init.then(all { phase' = "start", cmd' = "types", kb' = { hasModel: true, typechecks: true, dataOk: true, breaks: 0 }, exitCode' = -1, modelWritten' = false })
    .then(toExported).then(all { assert(exitCode == 0), stay })
}
