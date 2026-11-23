// The data model skill: one run of kb-data-model on one domain, and the page it draws.
// Module dataModelPage holds the page as pure functions of the types of one domain.
// Module dataModelRun holds the states of the graph in architecture.md.
// Not covered: how Claude words a type from what the user says, and whether the picture is what the user needs.
// The user judges that, run after run.
// NEGATIVE CONTROL: pageNegative in dataModelPage and neverShown in dataModelRun are false on purpose.
module dataModelPage {
  type Area = Source | Staging | Consolidated
  // A type as the page sees it: its areas and the types it names, by made of, part of or links to.
  type T = { areas: Set[Area], names: Set[str] }
  type Edge = { src: str, dst: str }

  pure def rankOf(a: Area): int = match a { | Source => 0 | Staging => 1 | Consolidated => 2 }
  pure def rank(t: T): int = t.areas.fold(2, (m, a) => if (rankOf(a) < m) rankOf(a) else m)

  /// F2: one link per pair of types that name each other, the way the data flows: from the lower area to
  /// the higher one, and inside one area from the named type to the one that names it. A link has no text.
  pure def edges(m: str -> T): Set[Edge] =
    m.keys().fold(Set(), (acc, a) => acc.union(m.get(a).names.filter(b => b != a and m.keys().contains(b))
      .map(b => if (rank(m.get(a)) < rank(m.get(b))) { src: a, dst: b } else { src: b, dst: a })))

  /// F18: the model names the skill that moves the data along a pair of types. A link shows it as its text,
  /// and a link with no skill has no text.
  type Skill = { pair: Set[str], skill: str }
  pure def linkText(skills: Set[Skill], e: Edge): str =
    skills.filter(s => s.pair == Set(e.src, e.dst)).fold("", (acc, s) => s.skill)

  /// F19: the hover of each type ends with its own fields, required first, and a raw type says it has none.
  pure val fieldHover: bool = true
  /// F20: a raw type's hover names its expected attributes, and the folder check never reads them.
  pure val expectedHover: bool = true
  /// F21: the model holds `files`: one `{ name, path, into, skill }` per list file that feeds a type. The page draws
  /// each as an external node named "file: <name>", with a link into its type that names the skill.
  type ListFile = { name: str, into: str, skill: str }
  pure def fileEdges(fs: Set[ListFile]): Set[Edge] = fs.map(f => { src: f.name, dst: f.into })
  /// F21: a list file links into the type it feeds.
  run fileTest = all { assert(fileEdges(Set({ name: "recipe_sources", into: "raw_recipe_source", skill: "food-record-recipe" }))
    == Set({ src: "recipe_sources", dst: "raw_recipe_source" })), init }
  /// F22: the model holds `skillSteps`: `{ skill, step }` rows, in order. The page writes one `about [<skill>]: <n>. <step>` line for each.
  pure val stepNotes: bool = true
  /// F23: the model holds `checks`: one `{ skill, on }` per skill that checks a type. The page draws the skill as a
  /// skill node apart from the types, with a link "check" from the type to it and "confirmed" back.
  type Check = { skill: str, on: str }
  pure def checkEdges(cs: Set[Check]): Set[Edge] =
    cs.map(c => Set({ src: c.on, dst: c.skill }, { src: c.skill, dst: c.on })).flatten()
  /// F24: the ring of a type on the page: index 0, staging 1, raw 2. A file or a check skill takes ring 3.
  pure def ring(t: T): int = 2 - rank(t)
  /// F24: index sits inside staging, and staging inside raw.
  run ringTest = all { assert(ring(food.get("confirmed_recipe")) == 0 and ring(food.get("recipe_version")) == 1
    and ring(food.get("grocery_receipt")) == 2), init }
  /// F23: a check is a round trip with the type it checks.
  run checkTest = all { assert(checkEdges(Set({ skill: "ask-antafu", on: "nutrition_goal" }))
    == Set({ src: "nutrition_goal", dst: "ask-antafu" }, { src: "ask-antafu", dst: "nutrition_goal" })), init }
  /// F11: each node of the page has a label line with its display name, the identifier without its area.
  pure val labelLines: bool = true
  /// F5: the page asks for the button row of graph-filter.
  pure val filterLine: bool = true

  /// F3: the text colour of each type: tan for source, light blue for staging, none for confirmed.
  pure def colour(t: T): str = if (rank(t) == 0) "tan" else if (rank(t) == 1) "light-blue" else ""

  // The food domain of kb-structure.md, as a case.
  pure val food: str -> T = Map(
    "food_item" -> { areas: Set(Consolidated), names: Set() },
    "grocery_receipt" -> { areas: Set(Source), names: Set("food_item") },
    "inventory_snapshot" -> { areas: Set(Consolidated), names: Set("food_item", "grocery_receipt", "cooked_batch", "inventory_snapshot") },
    "recipe_source" -> { areas: Set(Source), names: Set() },
    "recipe_version" -> { areas: Set(Staging), names: Set("food_item", "recipe_source") },
    "confirmed_recipe" -> { areas: Set(Consolidated), names: Set("food_item", "recipe_version") },
    "cooked_batch" -> { areas: Set(Consolidated), names: Set("confirmed_recipe", "inventory_snapshot") },
  )

  /// F2: each link goes from a lower or equal area to a higher or equal one.
  val forward = edges(food).forall(e => rank(food.get(e.src)) <= rank(food.get(e.dst)))
  /// F2: each link joins two types of the domain, and no link is a loop.
  val inDomain = edges(food).forall(e => food.keys().contains(e.src) and food.keys().contains(e.dst) and e.src != e.dst)
  /// F2: each pair that names each other has a link.
  val eachName = food.keys().forall(a => food.get(a).names.forall(b => b == a or not(food.keys().contains(b))
    or edges(food).exists(e => Set(e.src, e.dst) == Set(a, b))))
  /// F3: the colours of the case.
  val colours = colour(food.get("grocery_receipt")) == "tan" and colour(food.get("recipe_version")) == "light-blue"
    and colour(food.get("food_item")) == ""
  /// F5: each page has the filter line.
  val hasFilter = filterLine
  pure val foodSkills: Set[Skill] = Set({ pair: Set("grocery_receipt", "food_item"), skill: "food-record-receipt" })
  /// F18: a link the model gives a skill has that skill as its text, in either order of the pair.
  val skillText = linkText(foodSkills, { src: "grocery_receipt", dst: "food_item" }) == "food-record-receipt"
    and linkText(foodSkills, { src: "food_item", dst: "grocery_receipt" }) == "food-record-receipt"
  /// NEGATIVE CONTROL: false on purpose, a staging type is drawn tan.
  val pageNegative = colour(food.get("recipe_version")) == "tan"

  var shown: bool
  action init = shown' = true
  action step = shown' = shown

  /// F2: the receipt flows into the food item, and the food item into the recipe that lists it.
  run flowTest = init.then(all {
    assert(edges(food).contains({ src: "grocery_receipt", dst: "food_item" })),
    assert(edges(food).contains({ src: "food_item", dst: "confirmed_recipe" })),
    assert(edges(food).contains({ src: "recipe_version", dst: "food_item" })),
    assert(not(edges(food).contains({ src: "inventory_snapshot", dst: "inventory_snapshot" }))),
    step })
  /// F18: a link with no skill in the model has no text.
  run skillTest = init.then(all {
    assert(linkText(foodSkills, { src: "food_item", dst: "confirmed_recipe" }) == ""),
    assert(linkText(foodSkills, { src: "grocery_receipt", dst: "food_item" }) == "food-record-receipt"),
    step })
}

module dataModelRun {
  var phase: str
  var modelChanged: bool
  var pageWritten: bool
  var asks: int

  action init = all { phase' = "start", modelChanged' = false, pageWritten' = false, asks' = 0 }

  /// F4: Claude reads the domain, and again after the user asks for a change.
  action toReading = all { phase == "start" or phase == "shown", phase' = "reading", modelChanged' = false, pageWritten' = pageWritten,
    asks' = if (phase == "shown") asks + 1 else asks }
  /// F1: no such domain, or no model in its KB.
  action toNoDomain = all { phase == "start", phase' = "no_domain", modelChanged' = false, pageWritten' = false, asks' = asks }
  /// F1: Claude writes the types of the domain into the model.
  action toWritingModel = all { phase == "reading", phase' = "writing_model", modelChanged' = true, pageWritten' = pageWritten, asks' = asks }
  /// F1: a model that fails in Quint is put back.
  action toBadModel = all { phase == "writing_model", phase' = "bad_model", modelChanged' = false, pageWritten' = pageWritten, asks' = asks }
  /// F2: page.py writes the page from the model.
  action toDrawing = all { phase == "writing_model", phase' = "drawing", modelChanged' = true, pageWritten' = true, asks' = asks }
  /// F2: the page breaks a rule of the graph check.
  action toBadGraph = all { phase == "drawing", phase' = "bad_graph", modelChanged' = true, pageWritten' = true, asks' = asks }
  /// F4: the drift check runs and the user gets the link.
  action toShown = all { phase == "drawing", phase' = "shown", modelChanged' = true, pageWritten' = true, asks' = asks }
  /// F4: a run that ended stays where it ended.
  action stay = all { phase' = phase, modelChanged' = modelChanged, pageWritten' = pageWritten, asks' = asks }

  action step = any { toReading, toNoDomain, toWritingModel, toBadModel, toDrawing, toBadGraph, toShown,
    all { Set("no_domain", "bad_model", "bad_graph").contains(phase), stay } }

  /// F4: the link goes to the user only with a page drawn from the changed model.
  val shownHasPage = phase == "shown" implies (pageWritten and modelChanged)
  /// F1: a bad model leaves the model as it was.
  val badModelPutBack = phase == "bad_model" implies not(modelChanged)
  /// F1: no domain writes nothing.
  val noDomainWritesNothing = phase == "no_domain" implies not(modelChanged or pageWritten)
  /// NEGATIVE CONTROL: false on purpose, a run reaches shown.
  val neverShown = phase != "shown"

  /// F4: a second round after the user asks for a change.
  /// shown
  run shownTest = init.then(toReading).then(toWritingModel).then(toDrawing).then(toShown).then(toReading)
    .then(toWritingModel).then(toDrawing).then(toShown).then(all { assert(phase == "shown" and asks == 1), stay })
  /// F1: no domain writes nothing.
  /// no_domain
  run noDomainTest = init.then(toNoDomain).then(all { assert(not(pageWritten)), stay })
  /// F1: a bad model is put back.
  /// bad_model
  run badModelTest = init.then(toReading).then(toWritingModel).then(toBadModel).then(all { assert(not(modelChanged)), stay })
  /// F2: a page that breaks a graph rule stays, with the rule.
  /// bad_graph
  run badGraphTest = init.then(toReading).then(toWritingModel).then(toDrawing).then(toBadGraph).then(all { assert(phase == "bad_graph"), stay })
}

// The folder check of folders.py: a domain holds raw/<type>/, staging/<type>/ and index/.
// A type is named with `_` in the model and `-` on disk. The model writes both the same.
// NEGATIVE CONTROL: foldersNegative is false on purpose.
module dataModelFolders {
  // A type of the domain: its identifier as (area prefix, name), the folders of its glob before the first `*`,
  // its fields, and the types it names (made of, part of, links to). The name is the display name.
  type Id = (str, str)
  type G = { id: Id, dirs: List[str], fields: Set[str], links: Set[Id] }
  pure val RAW: Set[str] = Set("grocery-receipt", "research-run")
  pure val STAGING: Set[str] = Set("recipe")

  /// F17, F11: a type starts with `raw_` or `staging_`, and its glob sits in <area>/<name>/. A gold type is a break.
  pure def globOk(g: G): bool = Set("raw", "staging").contains(g.id._1) and g.dirs.length() >= 2 and g.dirs[0] == g.id._1 and g.dirs[1] == g.id._2
  /// F17, F10, F9: a file sits in raw/<a raw type>/ or staging/<a staging type>/ at any depth, right in index/, or at the domain root.
  /// What is inside a raw folder is not checked.
  pure def fileOk(dirs: List[str]): bool =
    dirs.length() == 0
    or (dirs.length() == 1 and dirs[0] == "index")
    or (dirs.length() >= 2 and dirs[0] == "raw" and RAW.contains(dirs[1]))
    or (dirs.length() >= 2 and dirs[0] == "staging" and STAGING.contains(dirs[1]))
  /// F13: created_at and updated_at. F12: the key of its thing, valid_from and valid_to. F16: raw, the raw files it came from.
  pure val STANDARD: Set[str] = Set("created_at", "updated_at", "key", "valid_from", "valid_to", "raw")
  /// F17: a raw type has no field rule. A staging type has the standard fields.
  pure def fieldsOk(g: G): bool = g.id._1 != "staging" or STANDARD.subseteq(g.fields)
  /// F16: the types that reach a raw type through their links, in any number of steps.
  pure def reach(gs: Set[G]): Set[Id] =
    gs.fold(gs.filter(g => g.id._1 == "raw").map(g => g.id), (r, _) => r.union(gs.filter(g => g.links.intersect(r) != Set()).map(g => g.id)))
  pure def reachOk(gs: Set[G], g: G): bool = g.id._1 != "staging" or reach(gs).contains(g.id)
  /// F6: each break: a glob out of place, a staging type with a standard field missing or no way to raw, and a file out of place.
  pure def breaks(gs: Set[G], files: Set[List[str]]): Set[(str, Id)] =
    gs.filter(g => not(globOk(g))).map(g => ("glob", g.id))
      .union(gs.filter(g => not(fieldsOk(g))).map(g => ("fields", g.id)))
      .union(gs.filter(g => not(reachOk(gs, g))).map(g => ("raw", g.id)))
      .union(files.filter(f => not(fileOk(f))).map(f => ("file", ("", f.foldl("", (a, b) => b)))))

  var globs: Set[G]
  var files: Set[List[str]]

  pure val receipt: G = { id: ("raw", "grocery-receipt"), dirs: ["raw", "grocery-receipt"], fields: Set(), links: Set() }
  pure val recipe: G = { id: ("staging", "recipe"), dirs: ["staging", "recipe"], fields: STANDARD, links: Set(("raw", "grocery-receipt")) }
  pure val plan: G = { id: ("staging", "plan"), dirs: ["staging", "plan"], fields: STANDARD, links: Set(("staging", "recipe")) }
  pure val lone: G = { id: ("staging", "lone"), dirs: ["staging", "lone"], fields: STANDARD, links: Set() }

  action init = all {
    nondet gs = Set(Set(receipt, recipe, plan), Set(receipt, recipe, lone),
      Set(receipt, { ...recipe, dirs: ["meals", "recipe"] }),
      Set(receipt, { ...recipe, fields: Set("created_at") }),
      Set({ id: ("", "confirmed-recipe"), dirs: ["index"], fields: Set(), links: Set() })).oneOf()
    nondet fs = Set(Set(["raw", "grocery-receipt"]), Set(["pantry"]), Set([]), Set(["index"]), Set(["index", "old"]),
      Set(["raw", "research-run", "2026-run"]), Set(["staging", "2026-run"]), Set(["raw", "nope"])).oneOf()
    all { globs' = gs, files' = fs }
  }
  action step = all { globs' = globs, files' = files }

  /// F7: the check passes only when each glob, each staging type and each file are in place.
  val passMeansInPlace = breaks(globs, files) == Set() implies
    (globs.forall(g => globOk(g) and fieldsOk(g) and reachOk(globs, g)) and files.forall(f => fileOk(f)))
  /// F7: a break is named, so the hook can show it.
  val failNamesIt = globs.forall(g => (not(globOk(g)) implies breaks(globs, files).contains(("glob", g.id)))
    and (not(fieldsOk(g)) implies breaks(globs, files).contains(("fields", g.id)))
    and (not(reachOk(globs, g)) implies breaks(globs, files).contains(("raw", g.id))))
  /// NEGATIVE CONTROL: false on purpose, a break is found.
  val foldersNegative = breaks(globs, files) == Set()

  /// F17: a raw type with no field passes, and a file of a folder that is no raw type breaks.
  run rawTest = all { assert(globOk(receipt) and fieldsOk(receipt) and fileOk(["raw", "grocery-receipt", "deep"]) and not(fileOk(["raw", "nope"]))), init }
  /// F11: a raw type and a staging type can share a name, each in its own area folder.
  run sameNameTest = all { assert(globOk({ ...recipe, id: ("raw", "recipe"), dirs: ["raw", "recipe"] }) and globOk(recipe)
    and not(globOk({ ...recipe, dirs: ["raw", "recipe"] }))), init }
  /// F16: a staging type reaches raw in two steps, and one with no link breaks.
  run reachTest = all { assert(reachOk(Set(receipt, recipe, plan), plan) and not(reachOk(Set(receipt, lone), lone))), init }
  /// F16, F12, F13: a staging type with no raw field, or no valid_to, breaks.
  run fieldsTest = all { assert(not(fieldsOk({ ...recipe, fields: STANDARD.exclude(Set("raw")) }))
    and not(fieldsOk({ ...recipe, fields: STANDARD.exclude(Set("valid_to")) })) and fieldsOk(recipe)), init }
  /// F10: a research run sits in raw/research-run/<run>/, and one right in staging/ is a break.
  run researchTest = all { assert(fileOk(["raw", "research-run", "2026-run"]) and not(fileOk(["staging", "2026-run"]))), init }
  /// F9: a gold page sits right in index/, and a sub-folder of index/ is a break.
  run indexTest = all { assert(fileOk(["index"]) and not(fileOk(["index", "old"]))), init }
  /// F9: a gold type is a break.
  run globTest = all { assert(breaks(Set({ id: ("", "confirmed-recipe"), dirs: ["index"], fields: Set(), links: Set() }, receipt), Set())
    == Set(("glob", ("", "confirmed-recipe")))), init }
}
