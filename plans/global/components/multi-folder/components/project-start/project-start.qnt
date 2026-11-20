// The project start: claude in the harness, with each folder of one project added.
module projectStart {
  pure val projectMap: str -> Set[str] = Map("shop" -> Set("/code/web", "/code/api", "/code/gone"))
  pure val onDisk = Set("/code/web", "/code/api")

  var phase: str          // asked, looked, check, started, unknown
  var name: str
  var added: Set[str]     // the folders passed to --add-dir
  var named: Set[str]     // the folders named as missing

  /// F1, F2: The user gives a project name.
  action initWith(n: str): bool = all { phase' = "asked", name' = n, added' = Set(), named' = Set() }
  action init = nondet n = Set("shop", "nope").oneOf() initWith(n)

  action keep(p: str, a: Set[str], m: Set[str]): bool = all { phase' = p, name' = name, added' = a, named' = m }
  /// F1: the script asks the map.
  action look = all { phase == "asked", keep("looked", added, named) }
  /// F2: an unknown project starts nothing.
  action unknown = all { phase == "looked", not(projectMap.keys().contains(name)), keep("unknown", Set(), Set()) }
  /// F3: keep the folders on disk, name the others.
  action check = all {
    phase == "looked", projectMap.keys().contains(name),
    keep("check", projectMap.get(name).intersect(onDisk), projectMap.get(name).exclude(onDisk)),
  }
  /// F1: claude starts with the kept folders.
  action start = all { phase == "check", keep("started", added, named) }
  /// F1: the run ends where it stopped.
  action done = all { Set("started", "unknown").contains(phase), keep(phase, added, named) }

  action step = any { look, unknown, check, start, done }

  /// F2: an unknown project adds no folder.
  val unknownAddsNothing = phase == "unknown" implies added == Set()
  /// F3: each added folder is on disk, and no folder is both added and named.
  val addedOnDisk = added.subseteq(onDisk) and added.intersect(named) == Set()
  /// F1: a start adds only folders of the project.
  val addedOfProject = phase == "started" implies added.subseteq(projectMap.get(name))
  /// NEGATIVE CONTROL: a start does add folders.
  val neverAdds = added == Set()

  /// F1, F3: the two folders on disk, and the missing one named.
  /// started
  run startTest = initWith("shop").then(look).then(check).then(start)
    .expect(added == Set("/code/web", "/code/api") and named == Set("/code/gone"))
  /// F2: an unknown name.
  /// unknown
  run unknownTest = initWith("nope").then(look).then(unknown).expect(phase == "unknown" and added == Set())
}
