// Code worktrees: project-start --worktree adds a worktree of each code repo in place of its main checkout.
module codeWorktrees {
  // Each folder of the project: its role, and if it is a git repo.
  pure val folders = Set("/a/web", "/b", "/kb", "/plain")
  pure val isRepo = Set("/a/web", "/b", "/kb")
  pure val isKb = Set("/kb")
  // The worktree folder of each repo, <repo>/.claude/worktrees/<name>.
  pure val wtOf: str -> str = Map("/a/web" -> "/a/web/wt", "/b" -> "/b/wt", "/kb" -> "/kb/wt")

  var phase: str            // asked, made, started
  var existing: Set[str]    // worktrees on disk
  var added: Set[str]
  var excluded: Set[str]    // repos whose .git/info/exclude names .claude/worktrees/
  var deleted: Set[str]     // worktrees or branches the script deleted

  /// F1: a worktree may already exist.
  action initWith(e: Set[str]): bool =
    all { phase' = "asked", existing' = e, added' = Set(), excluded' = Set(), deleted' = Set() }
  action init = nondet e = Set(Set(), Set("/b/wt")).oneOf() initWith(e)

  pure def code(f: str): bool = isRepo.contains(f) and not(isKb.contains(f))

  /// F1, F2, F3: make each missing worktree of a code repo, exclude it, and pick the folders to add.
  action make = all {
    phase == "asked", phase' = "made",
    existing' = existing.union(folders.filter(f => code(f)).map(f => wtOf.get(f))),
    added' = folders.map(f => if (code(f)) wtOf.get(f) else f),
    excluded' = folders.filter(f => code(f)),
    deleted' = deleted,
  }
  /// F4: claude starts with the folders, and they are printed.
  action start = all { phase == "made", phase' = "started", existing' = existing, added' = added, excluded' = excluded, deleted' = deleted }
  /// F4: the run ends at the start.
  action done = all { phase == "started", phase' = phase, existing' = existing, added' = added, excluded' = excluded, deleted' = deleted }
  action step = any { make, start, done }

  /// F1: no main checkout of a code repo is added.
  val noMainOfCode = added.forall(f => not(code(f)))
  /// F2: a KB and a plain folder stay as they are.
  val kbAndPlainKept = phase != "asked" implies Set("/kb", "/plain").subseteq(added)
  /// F3: each code repo with a worktree excludes it.
  val excludedEach = phase != "asked" implies excluded == folders.filter(f => code(f))
  /// F4: nothing is deleted.
  val neverDeletes = deleted == Set()
  /// NEGATIVE CONTROL: a start adds a worktree.
  val noWorktree = added.forall(f => not(existing.contains(f)))

  /// F1, F2, F3: a run with one worktree there already.
  /// started
  run startTest = initWith(Set("/b/wt")).then(make).then(start)
    .expect(added == Set("/a/web/wt", "/b/wt", "/kb", "/plain") and excluded == Set("/a/web", "/b"))
}
