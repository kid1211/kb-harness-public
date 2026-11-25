// The folder line under the status line: each code folder of the session, by its role and the
// folder name of its checkout.
module folderStatus {
  // The test world: web and its worktree, api, a KB, the harness, a folder in no repo, and a
  // repo whose role is off the list.
  type Entry = { name: str, role: str }
  pure val roleOf: str -> str = Map("/code/web" -> "frontend", "/code/web/.claude/worktrees/w" -> "frontend",
    "/code/api" -> "backend", "/kb" -> "KB", "/h" -> "tooling", "/tmp/notes" -> "frontend", "/odd" -> "weird")
  // The folder name of the top of each checkout, or "" for a folder in no repo.
  pure val topName: str -> str = Map("/code/web" -> "web", "/code/web/.claude/worktrees/w" -> "w",
    "/code/api" -> "api", "/kb" -> "kb", "/h" -> "h", "/tmp/notes" -> "", "/odd" -> "odd")
  // Each domain of the map and its folders.
  pure val domainMap: str -> Set[str] = Map("shop" -> Set("/code/web", "/code/api", "/kb"), "web" -> Set("/code/web"))
  pure def fullOf(a: Set[str]): Set[str] = domainMap.keys().filter(n => domainMap.get(n).subseteq(a))
  /// F6: the largest domains whose folders are all added.
  pure def domainsOf(a: Set[str]): Set[str] = fullOf(a).filter(n =>
    not(fullOf(a).exists(m => m != n and domainMap.get(n).subseteq(domainMap.get(m)))))
  pure val dirs = roleOf.keys()
  // A code folder: in a repo, with a role that is not KB or tooling. A role off the list shows too, as an error.
  pure def isCode(d: str): bool = topName.get(d) != "" and not(Set("", "KB", "tooling").contains(roleOf.get(d)))
  pure def entryOf(d: str): Entry = { name: topName.get(d), role: roleOf.get(d) }

  var phase: str          // input, group, quiet, shown
  var added: Set[str]
  var shown: Set[Entry]   // what the line prints
  var recorded: Set[str]  // the session file of the added folders
  var domains: Set[str]   // the session file `domain`, which the domains button reads

  /// F1: the status line gives the added folders.
  action initWith(a: Set[str]): bool = all { phase' = "input", added' = a, shown' = Set(), recorded' = Set(), domains' = Set() }
  action init = nondet a = dirs.powerset().oneOf() initWith(a)

  /// F4: no added folder, no line, and an empty session file.
  action quiet = all { phase == "input", added.size() == 0, phase' = "quiet", added' = added, shown' = Set(), recorded' = Set(), domains' = Set() }
  /// F2: the script finds the checkout and the role of each folder.
  action group = all { phase == "input", added.size() > 0, phase' = "group", added' = added, shown' = shown, recorded' = recorded, domains' = domains }
  /// F1, F2, F4, F5, F6: one entry per code folder, the domain, and the session file.
  action show = all { phase == "group", phase' = "shown", added' = added,
    shown' = added.filter(d => isCode(d)).map(d => entryOf(d)), recorded' = added, domains' = domainsOf(added) }
  /// F1: the line stays until the next update.
  action done = all { Set("quiet", "shown").contains(phase), phase' = phase, added' = added, shown' = shown, recorded' = recorded, domains' = domains }

  action step = any { quiet, group, show, done }

  /// F4: with no added folder, the line prints nothing.
  val quietWhenNone = phase == "quiet" implies shown == Set()
  /// F1, F2: each code folder shows, by its role and the folder name of its checkout.
  val eachCodeShown = phase == "shown" implies added.filter(d => isCode(d)).forall(d => shown.contains(entryOf(d)))
  /// F2: no KB, no harness, no folder in no repo.
  val onlyCode = phase == "shown" implies shown.forall(e => e.name != "" and not(Set("KB", "tooling").contains(e.role)))
  /// F6: the session file names the largest full domains.
  val domainShown = Set("quiet", "shown").contains(phase) implies domains == domainsOf(added)
  /// F4: at the end, the session file holds the added folders, no more and no less.
  val recordedAll = Set("quiet", "shown").contains(phase) implies recorded == added
  /// NEGATIVE CONTROL: a run with folders added always shows one.
  val neverEmpty = phase == "shown" implies shown.size() > 0

  /// F2, F5, F6: a repo and its worktree by their own names, a role off the list, and no KB, harness or plain folder.
  /// shown
  run twoFoldersTest = initWith(Set("/code/web", "/code/web/.claude/worktrees/w", "/code/api", "/kb", "/h", "/tmp/notes", "/odd"))
    .then(group).then(show)
    .expect(domainsOf(Set("/code/web")) == Set("web") and shown == Set({ name: "web", role: "frontend" }, { name: "w", role: "frontend" }, { name: "api", role: "backend" },
      { name: "odd", role: "weird" })
      and domains == Set("shop")
      and recorded == Set("/code/web", "/code/web/.claude/worktrees/w", "/code/api", "/kb", "/h", "/tmp/notes", "/odd"))
  /// F4: no added folder.
  /// quiet
  run noneTest = initWith(Set()).then(quiet).expect(phase == "quiet" and shown == Set())
}
