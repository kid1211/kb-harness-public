// One run of the branch guard on one Bash call.
//
// The hook reads the call, splits the command into its git parts, and judges
// each part in turn. The first part it refuses ends the run with exit 2.
// The inputs are picked once, at the start of the run.
//
// Not modelled: how the hook parses the text of the command into parts, and
// how it finds the repo of a part. Each part arrives here already sorted into
// a form, a place and a name. The tests of the script check the parse.
// 1-design.md explains each state, its invariants and its expected output.

module branchGuard {
  // switchNew: git switch with -c, -C or --orphan. branch: each form of
  // checkout, branch and stash branch that makes, renames or force-moves a
  // branch. checkoutName: git checkout with a name and no branch flag.
  val FORMS = Set("switch", "switchNew", "branch", "checkoutName", "worktreeAdd", "other")
  // Where git says the repo of the part is. gitError: a git call of the hook
  // failed, such as outside a repo.
  val PLACES = Set("harnessMain", "harnessLinked", "otherRepo", "gitError")
  // remoteOnly: a remote-tracking ref has the name, and no local branch has it.
  // unreadable: the hook cannot read the name, such as "$(...)".
  val NAMES = Set("local", "remoteOnly", "unreadable")

  type Part = { form: str, place: str, name: str }

  // The raw text on stdin holds the word git.
  var namesGit: bool
  // The hook can read the command and the cwd, split the command, and does
  // not fail itself.
  var inputOk: bool
  var parts: List[Part]
  // The part the hook judges next.
  var idx: int
  // "received", "parsed", "located", "allowed", "refused" or "failed_open".
  var phase: str
  // -1 until the run ends.
  var exitCode: int
  // "", "EnterWorktree" or "checkout": what the message on stderr names.
  var msg: str
  // The hook printed a warning on stderr.
  var warned: bool

  def isSwitch(p: Part): bool = p.form == "switch" or p.form == "switchNew"
  def needsRepo(p: Part): bool = p.form == "branch" or p.form == "checkoutName"
  // A git checkout with a name the hook cannot read: it passes before any git call.
  def isUnreadable(p: Part): bool = p.form == "checkoutName" and p.name == "unreadable"
  // A part in the main checkout of the harness that makes a branch.
  def makesBranchInMain(p: Part): bool =
    p.place == "harnessMain" and (p.form == "branch" or (p.form == "checkoutName" and p.name == "remoteOnly"))
  def refusable(p: Part): bool = isSwitch(p) or makesBranchInMain(p)
  def anyPart(f: Part => bool): bool = parts.indices().exists(i => f(parts[i]))
  def switchMsg(p: Part): str =
    if (p.form == "switchNew" and p.place == "harnessMain") "EnterWorktree" else "checkout"

  pure def mkPart(f: str, w: str, n: str): Part = { form: f, place: w, name: n }

  action init = {
    nondet g = Set(true, false).oneOf()
    nondet ok = Set(true, false).oneOf()
    nondet n = 0.to(2).oneOf()
    nondet f1 = FORMS.oneOf()
    nondet w1 = PLACES.oneOf()
    nondet n1 = NAMES.oneOf()
    nondet f2 = FORMS.oneOf()
    nondet w2 = PLACES.oneOf()
    nondet n2 = NAMES.oneOf()
    val ps = if (n == 0) List() else if (n == 1) List(mkPart(f1, w1, n1)) else List(mkPart(f1, w1, n1), mkPart(f2, w2, n2))
    all {
      namesGit' = g, inputOk' = ok, parts' = if (g) ps else List(),
      idx' = 0, phase' = "received", exitCode' = -1, msg' = "", warned' = false,
    }
  }

  action keepInputs = all { namesGit' = namesGit, inputOk' = inputOk, parts' = parts }

  /// R19: move quick exit.
  // No word git in the text: the hook exits at once, before it reads the JSON.
  action quickExit = all {
    phase == "received", not(namesGit), keepInputs,
    idx' = idx, phase' = "allowed", exitCode' = 0, msg' = "", warned' = warned,
  }

  /// R19: move fail open.
  // Bad JSON, a command the hook cannot split, or a failure of the hook itself:
  // the command runs, with a warning.
  action failOpen = all {
    phase == "received", namesGit, not(inputOk), keepInputs,
    idx' = idx, phase' = "failed_open", exitCode' = 0, msg' = "", warned' = true,
  }

  /// R19: move no git part.
  // No git part: the hook exits.
  action noGitPart = all {
    phase == "received", namesGit, inputOk, parts.length() == 0, keepInputs,
    idx' = idx, phase' = "allowed", exitCode' = 0, msg' = "", warned' = warned,
  }

  /// R19: move parse.
  action parse = all {
    phase == "received", namesGit, inputOk, parts.length() > 0, keepInputs,
    idx' = 0, phase' = "parsed", exitCode' = exitCode, msg' = msg, warned' = warned,
  }

  // The part passes. The next part, or exit 0 after the last one.
  action passPart(w: bool): bool = all {
    keepInputs, idx' = idx + 1, msg' = msg, warned' = w,
    if (idx + 1 < parts.length()) all { phase' = "parsed", exitCode' = exitCode }
    else all { phase' = "allowed", exitCode' = 0 },
  }

  action refuse(m: str): bool = all {
    keepInputs, idx' = idx, phase' = "refused", exitCode' = 2, msg' = m, warned' = warned,
  }

  /// R19: move refuse switch.
  // Each git switch is refused, in each repo.
  action refuseSwitch = all {
    phase == "parsed", isSwitch(parts[idx]), refuse(switchMsg(parts[idx])),
  }

  /// R19: move pass form.
  // git worktree add, and each form that makes no branch, pass with no git call.
  action passForm = all {
    phase == "parsed", not(isSwitch(parts[idx])), not(needsRepo(parts[idx])), passPart(warned),
  }

  /// R19: move locate.
  action locate = all {
    phase == "parsed", needsRepo(parts[idx]), keepInputs,
    idx' = idx, phase' = "located", exitCode' = exitCode, msg' = msg, warned' = warned,
  }

  /// R19: move judge.
  action judge = all {
    phase == "located",
    val p = parts[idx]
    if (isUnreadable(p)) passPart(warned)
    else if (p.place == "gitError") passPart(true)
    else if (makesBranchInMain(p)) refuse("EnterWorktree")
    else passPart(warned),
  }

  val finished = phase == "allowed" or phase == "refused" or phase == "failed_open"
  // The hook judged the whole command: it did not fail open.
  val judged = phase == "allowed" or phase == "refused"

  // The message for the part the hook refuses.
  def expectedMsg(p: Part): str = if (isSwitch(p)) switchMsg(p) else "EnterWorktree"

  /// R19: move crash.
  // The hook fails itself, such as with a traceback, in the middle of a run.
  // The wrapper of the script turns each exit but 2 into exit 0 with a warning.
  action crash = all {
    phase == "parsed" or phase == "located", keepInputs,
    idx' = idx, phase' = "failed_open", exitCode' = 0, msg' = "", warned' = true,
  }

  /// R19: move done.
  action done = all {
    finished, keepInputs, idx' = idx, phase' = phase, exitCode' = exitCode, msg' = msg, warned' = warned,
  }

  action step = any { quickExit, failOpen, noGitPart, parse, refuseSwitch, passForm, locate, judge, crash, done }

  /// R13: each git switch is refused, in each repo and each checkout.
  val switchRefused = (judged and anyPart(isSwitch)) implies exitCode == 2

  /// R23: a part that makes a branch in the main checkout of the harness is refused.
  val branchRefusedInHarnessMain =
    (judged and anyPart(p => p.form == "branch" and p.place == "harnessMain")) implies exitCode == 2

  /// R17: git checkout of a name that only a remote-tracking ref has is refused in the main checkout.
  val remoteOnlyRefused =
    (judged and anyPart(p => p.form == "checkoutName" and p.place == "harnessMain" and p.name == "remoteOnly"))
      implies exitCode == 2

  /// R17, R18, R19: the hook refuses only for a git switch or a branch made in the main checkout of the harness.
  /// So an unreadable name, a local branch, another repo and a linked worktree pass.
  val refusesOnlyForCause = (finished and exitCode == 2) implies refusable(parts[idx])

  /// R18: a command whose parts act only on other repos, with no git switch, passes.
  val otherReposPass =
    (judged and parts.indices().forall(i => parts[i].place != "harnessMain" and not(isSwitch(parts[i]))))
      implies exitCode == 0

  /// R19: git worktree add passes in each checkout.
  val worktreeAddPasses =
    (judged and parts.indices().forall(i => parts[i].form == "worktreeAdd")) implies exitCode == 0

  /// R21: input the hook cannot read or split, or a failure of the hook, lets the command run, with a warning.
  val failsOpen = (phase == "failed_open") implies (exitCode == 0 and warned)

  /// R21: a call with no word git passes at once, with nothing on stderr, even if its JSON is bad.
  val quietWithoutGit = (finished and not(namesGit)) implies (exitCode == 0 and not(warned))

  /// R21: a part whose git call failed passes, with a warning. An unreadable name passes before any git call.
  val gitErrorWarns =
    (finished and exitCode == 0 and anyPart(p => needsRepo(p) and not(isUnreadable(p)) and p.place == "gitError")) implies warned

  /// R23, R13: the message fits the refused part: git checkout for a git switch, EnterWorktree for a new
  /// branch in the main checkout of the harness.
  val messageFits = (finished and exitCode == 2) implies msg == expectedMsg(parts[idx])

  /// R23: invariant exit is zero or two.
  val exitIsZeroOrTwo = finished implies (exitCode == 0 or exitCode == 2)

  val allInvariants = and {
    switchRefused, branchRefusedInHarnessMain, remoteOnlyRefused, refusesOnlyForCause, otherReposPass,
    worktreeAddPasses, failsOpen, quietWithoutGit, gitErrorWarns, messageFits, exitIsZeroOrTwo,
  }

  // NEGATIVE CONTROL: must fail. Some run is refused.
  val negativeControl = not(phase == "refused")

  /// R23: move start with.
  action startWith(g: bool, ok: bool, ps: List[Part]): bool = all {
    namesGit' = g, inputOk' = ok, parts' = ps, idx' = 0, phase' = "received", exitCode' = -1, msg' = "", warned' = false,
  }

  /// R23: move start.
  action start(ok: bool, ps: List[Part]): bool = startWith(true, ok, ps)

  /// R13: git switch in a KB is refused, and the message names git checkout.
  run switchInKbTest =
    start(true, List(mkPart("switch", "otherRepo", "local")))
      .then(parse).then(refuseSwitch)
      .then(all { assert(exitCode == 2), assert(msg == "checkout"), done })

  /// R13: git switch -c in the main checkout of the harness names only EnterWorktree.
  run switchNewInMainTest =
    start(true, List(mkPart("switchNew", "harnessMain", "local")))
      .then(parse).then(refuseSwitch)
      .then(all { assert(exitCode == 2), assert(msg == "EnterWorktree"), done })

  /// R23: git checkout -b in the main checkout of the harness is refused.
  /// refused
  run branchInMainTest =
    start(true, List(mkPart("branch", "harnessMain", "local")))
      .then(parse).then(locate).then(judge)
      .then(all { assert(exitCode == 2), assert(msg == "EnterWorktree"), done })

  /// R19: the same command in a linked worktree passes.
  /// allowed
  run branchInWorktreeTest =
    start(true, List(mkPart("branch", "harnessLinked", "local")))
      .then(parse).then(locate).then(judge)
      .then(all { assert(exitCode == 0), assert(not(warned)), done })

  /// R17: a name that only a remote has is refused, a local one passes.
  run remoteOnlyTest =
    start(true, List(mkPart("checkoutName", "harnessMain", "local"), mkPart("checkoutName", "harnessMain", "remoteOnly")))
      .then(parse).then(locate).then(judge).then(locate).then(judge)
      .then(all { assert(exitCode == 2), assert(idx == 1), done })

  /// R17: a name the hook cannot read passes, so worktree-end keeps working.
  run unreadableNameTest =
    start(true, List(mkPart("checkoutName", "harnessMain", "unreadable")))
      .then(parse).then(locate).then(judge)
      .then(all { assert(exitCode == 0), done })

  /// R17, R21: an unreadable name passes with no warning, even where git would fail.
  run unreadableGitErrorTest =
    start(true, List(mkPart("checkoutName", "gitError", "unreadable")))
      .then(parse).then(locate).then(judge)
      .then(all { assert(exitCode == 0 and not(warned)), done })

  /// R18: git checkout -b in a KB passes.
  run branchInKbTest =
    start(true, List(mkPart("branch", "otherRepo", "local")))
      .then(parse).then(locate).then(judge)
      .then(all { assert(exitCode == 0), done })

  /// R21: a git error passes with a warning, and a later part is still judged.
  run gitErrorTest =
    start(true, List(mkPart("branch", "gitError", "local"), mkPart("branch", "harnessMain", "local")))
      .then(parse).then(locate).then(judge)
      .then(all { assert(phase == "parsed"), assert(warned), locate })
      .then(judge)
      .then(all { assert(exitCode == 2), done })

  /// R21: a call with no word git, even with bad JSON, passes with nothing on stderr.
  run quickExitTest =
    startWith(false, false, List())
      .then(quickExit)
      .then(all { assert(exitCode == 0), assert(not(warned)), done })

  /// R21: a failure of the hook in the middle of a run fails open, even for a git switch.
  /// failed_open
  run crashTest =
    start(true, List(mkPart("branch", "harnessMain", "local")))
      .then(parse).then(locate).then(crash)
      .then(all { assert(phase == "failed_open"), assert(exitCode == 0), assert(warned), done })

  /// R21: bad JSON, or a command the hook cannot split, fails open.
  run badInputTest =
    start(false, List())
      .then(failOpen)
      .then(all { assert(exitCode == 0), assert(warned), done })

  /// R19: git worktree add in the main checkout passes.
  run worktreeAddTest =
    start(true, List(mkPart("worktreeAdd", "harnessMain", "remoteOnly")))
      .then(parse).then(passForm)
      .then(all { assert(exitCode == 0), done })

  /// R23: a command with no git part exits at once.
  run noGitPartTest =
    start(true, List()).then(noGitPart).then(all { assert(exitCode == 0), done })
}
