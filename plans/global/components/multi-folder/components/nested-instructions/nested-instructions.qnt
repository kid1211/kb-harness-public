// The nested-instructions hook: after a call on a file outside the start folder, give
// Claude each CLAUDE.md between the file and its repo root, once per session. The root's
// own CLAUDE.md comes too when the repo was not added. A file Claude Code loaded itself
// is never given.
module nestedInstructions {
  // Test files: one in the start folder, two in an added repo, one in a repo not added.
  pure val outside = Set("/repo/web/src/a.ts", "/repo/web/b.ts", "/other/lib/c.ts")
  pure val files = outside.union(Set("/start/x.md"))
  // The CLAUDE.md files above each file, below its repo root.
  pure val above: str -> Set[str] = Map(
    "/repo/web/src/a.ts" -> Set("/repo/web/CLAUDE.md", "/repo/web/src/CLAUDE.md"),
    "/repo/web/b.ts" -> Set("/repo/web/CLAUDE.md"),
    "/other/lib/c.ts" -> Set("/other/lib/CLAUDE.md"),
    "/start/x.md" -> Set(),
  )
  // The CLAUDE.md of each file's repo root, and whether that repo was added.
  pure val topOf: str -> str = Map(
    "/repo/web/src/a.ts" -> "/repo/CLAUDE.md", "/repo/web/b.ts" -> "/repo/CLAUDE.md",
    "/other/lib/c.ts" -> "/other/CLAUDE.md", "/start/x.md" -> "/start/CLAUDE.md",
  )
  pure val added = Set("/repo/CLAUDE.md")
  pure def wanted(f: str): Set[str] =
    if (added.contains(topOf.get(f))) above.get(f) else above.get(f).union(Set(topOf.get(f)))

  var phase: str            // called, noted, walk, silent, given
  var file: str
  var given: Set[str]       // the CLAUDE.md files the hook gave in this session
  var loaded: Set[str]      // the CLAUDE.md files Claude Code loaded itself
  var out: Set[str]         // what this call gives

  /// F1, F2: a call on a file, with what the session got before.
  action initWith(f: str, g: Set[str], l: Set[str]): bool = all {
    phase' = "called", file' = f, given' = g, loaded' = l, out' = Set(),
  }
  action init = nondet f = files.oneOf() initWith(f, Set(), Set())

  action keep(p: str, g: Set[str], o: Set[str]): bool = all {
    phase' = p, file' = file, given' = g, loaded' = loaded, out' = o,
  }
  /// F6: Claude Code loaded a CLAUDE.md itself: the hook notes it, and gives nothing.
  action note(m: str): bool = all {
    phase == "called", phase' = "noted", file' = file, given' = given, loaded' = loaded.union(Set(m)), out' = Set(),
  }
  /// F3: a file in the start folder gets nothing.
  action inside = all { phase == "called", not(outside.contains(file)), keep("silent", given, Set()) }
  /// F1: the hook walks up from a file outside.
  action walk = all { phase == "called", outside.contains(file), keep("walk", given, Set()) }
  /// F2, F6: nothing new, nothing given.
  action nothingNew = all { phase == "walk", wanted(file).subseteq(given.union(loaded)), keep("silent", given, Set()) }
  /// F1, F2, F5: give each new CLAUDE.md, and mark it.
  action give = all {
    phase == "walk", not(wanted(file).subseteq(given.union(loaded))),
    keep("given", given.union(wanted(file).exclude(loaded)), wanted(file).exclude(given.union(loaded))),
  }
  /// F4: the call goes on: a new call starts.
  action goOn = all {
    Set("silent", "given", "noted").contains(phase),
    nondet f = files.oneOf()
    all { phase' = "called", file' = f, given' = given, loaded' = loaded, out' = Set() },
  }

  action step = any { nondet m = above.get("/repo/web/src/a.ts").oneOf() note(m), inside, walk, nothingNew, give, goOn }

  /// F2: a call never gives a CLAUDE.md the session had before.
  val onlyNew = phase == "given" implies out.size() > 0
  /// F3: a file in the start folder gives nothing.
  val insideSilent = not(outside.contains(file)) implies out == Set()
  /// F1, F5: each CLAUDE.md given sits above the file, or is the root of a repo not added.
  val givenAbove = out.subseteq(wanted(file))
  /// F6: a file Claude Code loaded is never given.
  val neverLoaded = out.intersect(loaded) == Set()
  /// NEGATIVE CONTROL: the hook does give a CLAUDE.md.
  val neverGives = out == Set()

  /// F1: a file deep in an added repo gives both CLAUDE.md files below the root.
  /// given
  run deepTest = initWith("/repo/web/src/a.ts", Set(), Set()).then(walk).then(give)
    .expect(out == Set("/repo/web/CLAUDE.md", "/repo/web/src/CLAUDE.md"))
  /// F2: a second file gives only what is new, here nothing.
  /// silent
  run onceTest = initWith("/repo/web/b.ts", Set("/repo/web/CLAUDE.md"), Set()).then(walk).then(nothingNew)
    .expect(phase == "silent" and out == Set())
  /// F3: a file in the start folder.
  /// silent
  run insideTest = initWith("/start/x.md", Set(), Set()).then(inside).expect(phase == "silent" and out == Set())
  /// F5: a file in a repo not added gives the root CLAUDE.md too.
  /// given
  run notAddedTest = initWith("/other/lib/c.ts", Set(), Set()).then(walk).then(give)
    .expect(out == Set("/other/lib/CLAUDE.md", "/other/CLAUDE.md"))
  /// F6: a CLAUDE.md that Claude Code loaded is noted, and later left out.
  /// noted
  run loadedTest = initWith("/repo/web/src/a.ts", Set(), Set()).then(note("/repo/web/src/CLAUDE.md"))
    .then(goOn).then(all { phase' = "called", file' = "/repo/web/src/a.ts", given' = given, loaded' = loaded, out' = Set() })
    .then(walk).then(give).expect(out == Set("/repo/web/CLAUDE.md"))
}
