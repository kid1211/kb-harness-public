// The add-dir context: /add-dir saves the folder, and the next prompt tells Claude the
// project, role and supporting docs of each folder it was not told yet, once per session.
module addDirContext {
  pure val folders = Set("/code/shop-web", "/code/shop-api", "/tmp/notes")
  // The context line of a folder: its project and docs from the map, or "no row".
  pure val contextOf: str -> str = Map(
    "/code/shop-web" -> "shop, code, docs /kb/shop",
    "/code/shop-api" -> "shop, code, docs /kb/shop",
    "/tmp/notes" -> "no row",
  )

  var phase: str          // called, recorded, told, silent
  var event: str          // added, prompt
  var dirs: Set[str]      // the session file of the added folders
  var told: Set[str]      // the folders Claude was told about
  var out: Set[str]       // the context lines this call gives

  /// F1, F5: a call of the hook, with what the session saved before.
  action initWith(ev: str, d: Set[str], t: Set[str]): bool = all {
    phase' = "called", event' = ev, dirs' = d, told' = t, out' = Set(),
  }
  action init = all {
    nondet ev = Set("added", "prompt").oneOf()
    nondet d = folders.powerset().oneOf()
    nondet t = d.powerset().oneOf()
    initWith(ev, d, t),
  }

  /// F5: /add-dir saves the folder, and gives nothing, since Claude Code drops the output.
  action record(f: str): bool = all {
    phase == "called", event == "added",
    phase' = "recorded", event' = event, dirs' = dirs.union(Set(f)), told' = told, out' = Set(),
  }
  /// F1, F2: a prompt tells Claude each saved folder it was not told yet.
  action tell = all {
    phase == "called", event == "prompt", not(dirs.subseteq(told)),
    phase' = "told", event' = event, dirs' = dirs, told' = told.union(dirs),
    out' = dirs.exclude(told).map(f => contextOf.get(f)),
  }
  /// F3, F4: nothing new, nothing given, and the prompt goes on.
  action quiet = all {
    phase == "called", event == "prompt", dirs.subseteq(told),
    phase' = "silent", event' = event, dirs' = dirs, told' = told, out' = Set(),
  }
  /// F4: the next call starts with what this one saved.
  action goOn = all {
    Set("recorded", "told", "silent").contains(phase),
    nondet ev = Set("added", "prompt").oneOf()
    all { phase' = "called", event' = ev, dirs' = dirs, told' = told, out' = Set() },
  }

  action step = any { nondet f = folders.oneOf() record(f), tell, quiet, goOn }

  /// F5: a saved folder stays saved, and the add itself gives nothing.
  val recordQuiet = phase == "recorded" implies out == Set()
  /// F1: each line given is the context of a saved folder.
  val toldFromDirs = out.forall(c => dirs.exists(f => contextOf.get(f) == c))
  /// F2: Claude is told only what is saved.
  val toldSaved = told.subseteq(dirs)
  /// NEGATIVE CONTROL: false on purpose, since a prompt after an add tells Claude.
  val neverTells = out == Set()

  /// F5: /add-dir saves the folder.
  /// recorded
  run addTest = initWith("added", Set(), Set()).then(record("/code/shop-web"))
    .expect(dirs == Set("/code/shop-web") and out == Set())
  /// F1: the next prompt tells Claude the folder's project and docs.
  /// told
  run tellTest = initWith("prompt", Set("/code/shop-web", "/tmp/notes"), Set("/tmp/notes")).then(tell)
    .expect(out == Set("shop, code, docs /kb/shop") and told == Set("/code/shop-web", "/tmp/notes"))
  /// F2: a folder told before is not told again.
  /// silent
  run onceTest = initWith("prompt", Set("/code/shop-web"), Set("/code/shop-web")).then(quiet)
    .expect(phase == "silent" and out == Set())
}
