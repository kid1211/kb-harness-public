// The project map: one page, one row per folder with its project. A script looks up
// the folders of a project, the project of a path, or the list of projects.
module projectMap {
  // A row of the map page.
  type Row = { project: str, folder: str }

  // The map of a test machine: two folders of one project, one of another.
  pure val rows: Set[Row] = Set(
    { project: "shop", folder: "/code/shop-web" },
    { project: "shop", folder: "/code/shop-api" },
    { project: "personal", folder: "/kb/personal" },
    { project: "admin", folder: "/code/shop-web/admin" },
  )
  // Which folder holds which path. A path in no folder of the map has no pair.
  pure val under: Set[(str, str)] = Set(
    ("/code/shop-web/src/a.ts", "/code/shop-web"),
    ("/code/shop-api", "/code/shop-api"),
    ("/kb/personal/x.md", "/kb/personal"),
    ("/code/shop-web/admin/x.ts", "/code/shop-web"),
    ("/code/shop-web/admin/x.ts", "/code/shop-web/admin"),
  )
  // Which folder of the map sits inside which: the inner one wins.
  pure val inside: Set[(str, str)] = Set(("/code/shop-web/admin", "/code/shop-web"))
  // The folder name the fallback prints: the last folder of the path, or the folder of a file.
  pure val nameOf: str -> str = Map("/tmp/other" -> "other", "/tmp/other/a.ts" -> "other")
  pure def nameAt(p: str): str = if (nameOf.keys().contains(p)) nameOf.get(p) else p
  pure val paths = Set("/code/shop-web/src/a.ts", "/code/shop-api", "/kb/personal/x.md", "/code/shop-web/admin/x.ts", "/tmp/other", "/tmp/other/a.ts")
  pure val names = Set("shop", "personal", "nope")

  pure def projectsOf(m: Set[Row]): Set[str] = m.map(r => r.project)
  pure def foldersOf(m: Set[Row], p: str): Set[str] = m.filter(r => r.project == p).map(r => r.folder)
  pure def homeOf(m: Set[Row], path: str): Set[str] =
    under.filter(u => u._1 == path).map(u => u._2).filter(f => m.exists(r => r.folder == f))
  // The innermost folder that holds the path: no other holder sits inside it.
  pure def innerOf(m: Set[Row], path: str): Set[str] =
    homeOf(m, path).filter(f => not(homeOf(m, path).exists(k => inside.contains((k, f)))))

  var phase: str          // asked, read, folders, project, fallback, listed, no_map
  var mapExists: bool
  var kind: str           // folders, project, list
  var arg: str            // the project name or the path
  var out: Set[str]       // what the script prints

  /// F1, F2: a call starts with its kind and its argument.
  action initWith(e: bool, k: str, a: str): bool = all {
    phase' = "asked", mapExists' = e, kind' = k, arg' = a, out' = Set(),
  }
  action init = all {
    nondet e = Set(true, false).oneOf()
    nondet k = Set("folders", "project", "list").oneOf()
    nondet a = names.union(paths).oneOf()
    initWith(e, k, a),
  }

  action keep(p: str, o: Set[str]): bool = all {
    phase' = p, out' = o, mapExists' = mapExists, kind' = kind, arg' = arg,
  }

  /// F1: the script reads the map page first.
  action read = all { phase == "asked", keep("read", Set()) }

  /// F1: no map page, no answer, and the script says so.
  action noMap = all { phase == "read", not(mapExists), keep("no_map", Set()) }

  /// F2: the folders of a known project.
  action folders = all {
    phase == "read", mapExists, kind == "folders", projectsOf(rows).contains(arg),
    keep("folders", foldersOf(rows, arg)),
  }
  /// F2: an unknown project lists the projects.
  action unknownProject = all {
    phase == "read", mapExists, kind == "folders", not(projectsOf(rows).contains(arg)),
    keep("listed", projectsOf(rows)),
  }
  /// F2: the project of the folder that holds the path.
  action project = all {
    phase == "read", mapExists, kind == "project", homeOf(rows, arg).size() > 0,
    keep("project", rows.filter(r => innerOf(rows, arg).contains(r.folder)).map(r => r.project)),
  }
  /// F3: a path on no row prints its own folder name, with no error.
  action fallback = all {
    phase == "read", mapExists, kind == "project", homeOf(rows, arg).size() == 0,
    keep("fallback", Set(nameAt(arg))),
  }
  /// F1: the list of projects.
  action list = all { phase == "read", mapExists, kind == "list", keep("listed", projectsOf(rows)) }

  /// F1: the look-up ends where it printed.
  action done = all {
    Set("folders", "project", "fallback", "listed", "no_map").contains(phase), keep(phase, out),
  }

  action step = any { read, noMap, folders, unknownProject, project, fallback, list, done }

  /// F1: with no map, the script prints nothing.
  val noMapPrintsNothing = phase == "no_map" implies out == Set()
  /// F2: each folder printed belongs to the project asked for.
  val foldersMatch = phase == "folders" implies out.forall(f => rows.contains({ project: arg, folder: f }))
  /// F2: a project look-up prints one project, the one of the innermost folder that holds the path.
  val projectMatch = phase == "project" implies
    (out.size() == 1 and out.forall(p => foldersOf(rows, p).exists(f => innerOf(rows, arg).contains(f))))
  /// F3: a path the map does not know never reaches an error, it falls back.
  val unknownFallsBack = (phase == "fallback") implies (homeOf(rows, arg).size() == 0 and out == Set(nameAt(arg)))
  /// NEGATIVE CONTROL: false on purpose, since a known project prints its folders.
  val neverFolders = phase != "folders"

  /// F2: both folders of the shop project.
  /// folders
  run foldersTest = initWith(true, "folders", "shop").then(read).then(folders)
    .expect(out == Set("/code/shop-web", "/code/shop-api"))
  /// F2: a file deep in a folder gives the project of that folder.
  /// project
  run projectTest = initWith(true, "project", "/code/shop-web/src/a.ts").then(read).then(project)
    .expect(out == Set("shop"))
  /// F3: a file in no folder of the map gives the name of its folder.
  /// fallback
  run fallbackTest = initWith(true, "project", "/tmp/other/a.ts").then(read).then(fallback)
    .expect(phase == "fallback" and out == Set("other"))
  /// F2: a nested folder wins over the folder that holds it.
  /// project
  run nestedTest = initWith(true, "project", "/code/shop-web/admin/x.ts").then(read).then(project)
    .expect(out == Set("admin"))
  /// F2: an unknown project name lists the projects.
  /// listed
  run unknownTest = initWith(true, "folders", "nope").then(read).then(unknownProject)
    .expect(out == Set("shop", "personal", "admin"))
  /// F1: no map page.
  /// no_map
  run noMapTest = initWith(false, "list", "shop").then(read).then(noMap).expect(phase == "no_map" and out == Set())
  /// F1: list prints each project.
  /// listed
  run listTest = initWith(true, "list", "shop").then(read).then(list).expect(out == Set("shop", "personal", "admin"))
}
