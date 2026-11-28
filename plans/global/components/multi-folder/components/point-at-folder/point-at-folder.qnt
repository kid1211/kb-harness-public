// Point at folder: --from adds the git root of a folder, and starts its project on the map.
module pointAtFolder {
  // The test world: /a/web/src/lib is pointed at. Its git root is /a/web. /x is on no row.
  pure val projectOf: str -> str = Map("/a/web/src/lib" -> "p", "/x" -> "")
  pure val siblings: str -> Set[str] = Map("p" -> Set("/a", "/b", "/kb"))
  pure val gitRoot: str -> str = Map("/a/web/src/lib" -> "/a/web", "/x" -> "/x")

  var phase: str         // asked, started, unmapped
  var folder: str
  var added: Set[str]    // folders passed to --add-dir
  var askMap: bool       // the script asks the user for a map row

  /// F1: the user points at a folder.
  action initWith(f: str): bool = all { phase' = "asked", folder' = f, added' = Set(), askMap' = false }
  action init = nondet f = Set("/a/web/src/lib", "/x").oneOf() initWith(f)

  /// F1, F2: a mapped folder starts its project, with its git root.
  action start = all { phase == "asked", projectOf.get(folder) != "", phase' = "started", folder' = folder,
    added' = siblings.get(projectOf.get(folder)).union(Set(gitRoot.get(folder))), askMap' = false }
  /// F3: a folder on no row starts nothing, and asks for a row.
  action unmapped = all { phase == "asked", projectOf.get(folder) == "", phase' = "unmapped", folder' = folder,
    added' = Set(), askMap' = true }
  /// F3: the run ends where it stopped.
  action done = all { Set("started", "unmapped").contains(phase), phase' = phase, folder' = folder, added' = added, askMap' = askMap }
  action step = any { start, unmapped, done }

  /// F1: a start adds each sibling of the project.
  val startAddsSiblings = (phase == "started") implies siblings.get(projectOf.get(folder)).subseteq(added)
  /// F2: a start adds the git root, and no folder below it. A folder in no repo is its own root.
  val startAddsRoot = (phase == "started") implies (added.contains(gitRoot.get(folder))
    and (gitRoot.get(folder) != folder implies not(added.contains(folder))))
  /// F3: a folder on no row adds nothing and asks for a row.
  val unmappedAsks = (phase == "unmapped") implies (askMap and added == Set())
  /// NEGATIVE CONTROL: no run asks the user for a map row.
  val neverAsksMap = not(askMap)

  /// F1, F2: a start from /a/web/src/lib.
  /// started
  run startTest = initWith("/a/web/src/lib").then(start).expect(added == Set("/a", "/b", "/kb", "/a/web"))
  /// F3: a folder on no row.
  /// unmapped
  run unmappedTest = initWith("/x").then(unmapped).expect(askMap and added == Set())
}
