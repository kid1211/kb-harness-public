// The folder pane: a button opens a side pane with two main parts, the coding folders and the
// KBs of the session, then a hidden part of the loaded instructions files and a warning.
module folderPane {
  // The context of each folder, as folder-context.py gives it. "" is no row.
  // docs: the KB folders that the map gives the project of the folder.
  type Ctx = { folder: str, project: str, role: str, docs: Set[str] }
  pure val ctxOf: str -> Ctx = Map(
    "/h" -> { folder: "/h", project: "harness", role: "tooling", docs: Set("/kb/personal") },
    "/code/web" -> { folder: "/code/web", project: "shop", role: "code", docs: Set("/kb/shop") },
    "/code/api" -> { folder: "/code/api", project: "shop", role: "code", docs: Set("/kb/shop") },
    "/kb/personal" -> { folder: "/kb/personal", project: "personal", role: "KB", docs: Set() },
    "/tmp/notes" -> { folder: "/tmp/notes", project: "", role: "", docs: Set() },
  )
  pure val added = Set("/code/web", "/code/api", "/kb/personal", "/tmp/notes")
  pure val start = "/h"

  pure def isKb(f: str): bool = ctxOf.get(f).role == "KB"
  /// F2: each added folder that is not a KB, less the start folder.
  pure def codingOf(fs: Set[str]): Set[str] = fs.filter(f => not(isKb(f)) and f != start)
  /// F3, F4: each added KB folder, and each KB of the map for a project of the session.
  pure def kbsOf(fs: Set[str]): Set[str] =
    fs.filter(f => isKb(f)).union(fs.union(Set(start)).fold(Set(), (acc, f) => acc.union(ctxOf.get(f).docs)))
      .exclude(Set(start))

  var phase: str              // closed, pressed, loading, shown
  var isOpen: bool
  var dirs: Set[str]          // the session file of the added folders
  var coding: Set[str]
  var kbs: Set[str]
  var notAdded: Set[str]      // the KBs of the map that are not added
  var loaded: Set[str]        // the session file of the instructions files
  var instructions: Set[str]  // what the instructions part lists
  var showInstructions: bool  // the instructions part, with its warning, is shown

  action keepData(p: str, o: bool): bool = all {
    phase' = p, isOpen' = o, dirs' = dirs, coding' = coding, kbs' = kbs, notAdded' = notAdded,
    loaded' = loaded, instructions' = instructions, showInstructions' = showInstructions,
  }
  /// F1, F9: the session starts with the pane closed and the instructions part hidden.
  action initWith(d: Set[str], l: Set[str]): bool = all {
    phase' = "closed", isOpen' = false, dirs' = d, coding' = Set(), kbs' = Set(), notAdded' = Set(),
    loaded' = l, instructions' = Set(), showInstructions' = false,
  }
  action init = nondet d = added.powerset().oneOf() initWith(d, Set("/h/CLAUDE.md"))

  /// F1: The user presses the button.
  action press = all { Set("closed", "shown").contains(phase), keepData("pressed", isOpen) }
  /// F1: a press on an open pane closes it.
  action close = all { phase == "pressed", isOpen, keepData("closed", false) }
  /// F1: a press on a closed pane opens it.
  action open = all { phase == "pressed", not(isOpen), keepData("loading", true) }
  /// F2, F3, F4, F6: the pane draws from the session files and the map.
  action draw = all {
    phase == "loading", phase' = "shown", isOpen' = true, dirs' = dirs, loaded' = loaded,
    coding' = codingOf(dirs), kbs' = kbsOf(dirs), notAdded' = kbsOf(dirs).exclude(dirs),
    instructions' = loaded, showInstructions' = showInstructions,
  }
  /// F9: the button of the instructions part shows it, or hides it.
  action toggleInstructions = all {
    phase == "shown", phase' = phase, isOpen' = isOpen, dirs' = dirs, coding' = coding, kbs' = kbs,
    notAdded' = notAdded, loaded' = loaded, instructions' = instructions, showInstructions' = not(showInstructions),
  }
  /// F5: a new /add-dir: the next draw shows it.
  action addDir(f: str): bool = all {
    phase == "shown", phase' = "loading", isOpen' = true, dirs' = dirs.union(Set(f)), coding' = coding,
    kbs' = kbs, notAdded' = notAdded, loaded' = loaded, instructions' = instructions,
    showInstructions' = showInstructions,
  }

  action step = any { press, close, open, draw, toggleInstructions, nondet f = added.oneOf() addDir(f) }

  /// F2: the start folder is in no part.
  val noStart = phase == "shown" implies not(coding.contains(start)) and not(kbs.contains(start))
  /// F2, F3: each added folder is in one part: coding or KBs.
  val eachAddedOnce = phase == "shown" implies
    dirs.exclude(Set(start)).forall(f => coding.contains(f) != kbs.contains(f))
  /// F3, F4: the KBs part holds the KBs of the map, and marks those not added.
  val kbsFromMap = phase == "shown" implies kbs == kbsOf(dirs) and notAdded == kbs.exclude(dirs)
  /// F6: the instructions part lists each instructions file of the session file.
  val instructionsListed = phase == "shown" implies instructions == loaded
  /// NEGATIVE CONTROL: false on purpose, since two code folders share the coding part.
  val neverShared = phase == "shown" implies coding.size() < 2

  /// F2, F3, F4: the coding part has both code folders and the folder on no row, not the start folder.
  /// The KBs part has the added KB and the KB of the shop project, marked not added.
  /// shown
  run drawTest = initWith(added, Set("/h/CLAUDE.md")).then(press).then(open).then(draw)
    .expect(coding == Set("/code/web", "/code/api", "/tmp/notes")
      and kbs == Set("/kb/personal", "/kb/shop") and notAdded == Set("/kb/shop")
      and instructions == Set("/h/CLAUDE.md") and not(showInstructions))
  /// F9: a press on the button of the instructions part shows it.
  /// shown
  run instructionsTest = initWith(Set(), Set("/h/CLAUDE.md")).then(press).then(open).then(draw)
    .then(toggleInstructions).expect(showInstructions)
  /// F1: a press on the open pane closes it.
  /// closed
  run closeTest = initWith(Set(), Set()).then(press).then(open).then(draw).then(press).then(close)
    .expect(phase == "closed" and not(isOpen))
  /// F5: an add redraws the pane with the new folder.
  /// shown
  run addTest = initWith(Set(), Set()).then(press).then(open).then(draw).then(addDir("/code/web")).then(draw)
    .expect(coding.contains("/code/web"))
}
