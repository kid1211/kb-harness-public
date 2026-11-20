// The folder part of the status line: each added folder by name, grouped under its project.
module folderStatus {
  // The project of each folder on a test map. A folder not here has no project.
  pure val projectOf: str -> str = Map("/code/shop-web" -> "shop", "/code/shop-api" -> "shop")
  pure val dirs = Set("/code/shop-web", "/code/shop-api", "/tmp/notes")

  // A group: a project (or "" for a folder on no row) and its folders.
  type Group = { project: str, folders: Set[str] }

  pure def keyOf(d: str): str = if (projectOf.keys().contains(d)) projectOf.get(d) else ""
  pure def groupsOf(added: Set[str]): Set[Group] =
    added.filter(d => keyOf(d) != "").map(d => keyOf(d))
      .map(p => { project: p, folders: added.filter(d => keyOf(d) == p) })
      .union(added.filter(d => keyOf(d) == "").map(d => { project: "", folders: Set(d) }))

  var phase: str          // input, group, quiet, shown
  var added: Set[str]
  var shown: Set[Group]   // what the part prints
  var recorded: Set[str]  // the session file of the added folders

  /// F1, F3: the status line gives the added folders.
  action initWith(a: Set[str]): bool = all { phase' = "input", added' = a, shown' = Set(), recorded' = Set() }
  action init = nondet a = dirs.powerset().oneOf() initWith(a)

  /// F3, F4: no added folder, no part, and an empty session file.
  action quiet = all { phase == "input", added.size() == 0, phase' = "quiet", added' = added, shown' = Set(), recorded' = Set() }
  /// F2: the script asks the map for each folder's project.
  action group = all { phase == "input", added.size() > 0, phase' = "group", added' = added, shown' = shown, recorded' = recorded }
  /// F1, F2, F4: one entry per project, and one per folder on no row. The session file holds the folders.
  action show = all { phase == "group", phase' = "shown", added' = added, shown' = groupsOf(added), recorded' = added }
  /// F1: the part stays until the next update.
  action done = all { Set("quiet", "shown").contains(phase), phase' = phase, added' = added, shown' = shown, recorded' = recorded }

  action step = any { quiet, group, show, done }

  /// F3: with no added folder, the part prints nothing.
  val quietWhenNone = phase == "quiet" implies shown == Set()
  /// F1: each added folder shows, in some group.
  val eachFolderShown = phase == "shown" implies added.forall(d => shown.exists(g => g.folders.contains(d)))
  /// F2: each project shows once.
  val projectOnce = phase == "shown" implies
    shown.filter(g => g.project != "").forall(g => shown.filter(h => h.project == g.project).size() == 1)
  /// F4: at the end, the session file holds the added folders, no more and no less.
  val recordedAll = Set("quiet", "shown").contains(phase) implies recorded == added
  /// NEGATIVE CONTROL: the shop project does show, with its two folders.
  val neverTwoInOne = phase == "shown" implies shown.forall(g => g.folders.size() < 2)

  /// F2: two folders of one project make one group.
  /// shown
  run twoFoldersTest = initWith(Set("/code/shop-web", "/code/shop-api", "/tmp/notes")).then(group).then(show)
    .expect(shown == Set({ project: "shop", folders: Set("/code/shop-web", "/code/shop-api") }, { project: "", folders: Set("/tmp/notes") })
      and recorded == Set("/code/shop-web", "/code/shop-api", "/tmp/notes"))
  /// F3: no added folder.
  /// quiet
  run noneTest = initWith(Set()).then(quiet).expect(phase == "quiet" and shown == Set())
}
