// The domains pane: a button opens a side pane. Its top part names the selected domain and the
// added folders. Its Selecting part lists each domain of the map: a click prints the /add-dir lines
// of its folders in the chat. At the bottom, a hidden part of the loaded instructions files.
module folderPane {
  // The test map: each domain and its folders.
  pure val domainsOf: str -> Set[str] = Map(
    "mf-web" -> Set("/t/web"), "mf-api" -> Set("/t/api"), "mf-both" -> Set("/t/web", "/t/api"),
    "trade" -> Set("/p/trade"))
  pure val names = domainsOf.keys()
  pure val start = "/h"
  pure val folders = Set("/t/web", "/t/api", "/p/trade", "/tmp/notes")

  /// F12: the largest domains whose folders are all added.
  pure def full(d: Set[str]): Set[str] = names.filter(n => domainsOf.get(n).subseteq(d))
  pure def selectedOf(d: Set[str]): Set[str] =
    full(d).filter(n => not(full(d).exists(m => m != n and domainsOf.get(n).subseteq(domainsOf.get(m)))))

  var phase: str              // closed, pressed, loading, shown, picked
  var isOpen: bool
  var dirs: Set[str]          // the session file of the added folders
  var selected: Set[str]      // the Selected part: the domain
  var listed: Set[str]        // the Selected part: the added folders
  var addLines: Set[str]      // a click: the folders of its /add-dir lines
  var switchTo: str           // a click: the domain of the new-session command, or ""
  var loaded: Set[str]        // the session file of the instructions files
  var instructions: Set[str]  // what the instructions part lists
  var showInstructions: bool

  action keepData(p: str, o: bool): bool = all {
    phase' = p, isOpen' = o, dirs' = dirs, selected' = selected, listed' = listed, addLines' = addLines,
    switchTo' = switchTo, loaded' = loaded, instructions' = instructions, showInstructions' = showInstructions,
  }
  /// F1, F9: the session starts with the pane closed and the instructions part hidden.
  action initWith(d: Set[str], l: Set[str]): bool = all {
    phase' = "closed", isOpen' = false, dirs' = d, selected' = Set(), listed' = Set(), addLines' = Set(),
    switchTo' = "", loaded' = l, instructions' = Set(), showInstructions' = false,
  }
  action init = nondet d = folders.powerset().oneOf() initWith(d, Set("/h/CLAUDE.md"))

  /// F1: the user presses the button.
  action press = all { Set("closed", "shown", "picked").contains(phase), keepData("pressed", isOpen) }
  /// F1: a press on an open pane closes it.
  action close = all { phase == "pressed", isOpen, keepData("closed", false) }
  /// F1: a press on a closed pane opens it.
  action open = all { phase == "pressed", not(isOpen), keepData("loading", true) }
  /// F12, F6: the pane draws from the session files and the map.
  action draw = all {
    phase == "loading", phase' = "shown", isOpen' = true, dirs' = dirs, selected' = selectedOf(dirs),
    listed' = dirs.exclude(Set(start)), addLines' = Set(), switchTo' = "", loaded' = loaded,
    instructions' = loaded, showInstructions' = showInstructions,
  }
  /// F13, F14: a click on a domain prints its /add-dir lines, and a new-session command if the
  /// session holds a folder of no part of it. The pane closes.
  action pick(n: str): bool = all {
    Set("shown", "picked").contains(phase), phase' = "picked", isOpen' = false, dirs' = dirs,
    selected' = selected, listed' = listed, addLines' = domainsOf.get(n).exclude(dirs),
    switchTo' = if (listed.exclude(domainsOf.get(n)).size() > 0) n else "",
    loaded' = loaded, instructions' = instructions, showInstructions' = showInstructions,
  }
  /// F9: the button of the instructions part shows it, or hides it.
  action toggleInstructions = all {
    phase == "shown", phase' = phase, isOpen' = isOpen, dirs' = dirs, selected' = selected, listed' = listed,
    addLines' = addLines, switchTo' = switchTo, loaded' = loaded, instructions' = instructions,
    showInstructions' = not(showInstructions),
  }
  /// F5: a new /add-dir: the next draw shows it.
  action addDir(f: str): bool = all {
    Set("shown", "picked").contains(phase), phase' = "loading", isOpen' = true, dirs' = dirs.union(Set(f)),
    selected' = selected, listed' = listed, addLines' = addLines, switchTo' = switchTo, loaded' = loaded,
    instructions' = instructions, showInstructions' = showInstructions,
  }

  action step = any {
    press, close, open, draw, toggleInstructions,
    nondet n = names.oneOf() pick(n),
    nondet f = folders.oneOf() addDir(f),
  }

  /// F12: the Selected part names the largest full domains, and each added folder but the start folder.
  val selectedLargest = Set("shown", "picked").contains(phase) implies
    (selected == selectedOf(dirs) and listed == dirs.exclude(Set(start)))
  /// F13: a click prints a line for each folder of the domain not added yet, and closes the pane.
  val pickAddsMissing = phase == "picked" implies (addLines.forall(f => not(dirs.contains(f))) and not(isOpen))
  /// F14: a new-session command only when the session holds a folder outside the domain.
  val switchWhenOther = phase == "picked" and switchTo != "" implies
    listed.exclude(domainsOf.get(switchTo)).size() > 0
  /// F6: the instructions part lists each instructions file of the session file.
  val instructionsListed = Set("shown", "picked").contains(phase) implies instructions == loaded
  /// NEGATIVE CONTROL: false on purpose, since a click with other folders added gives the command.
  val neverSwitch = switchTo == ""

  /// F12: web and api added: the selected domain is mf-both, not mf-web or mf-api.
  /// shown
  run drawTest = initWith(Set("/t/web", "/t/api"), Set("/h/CLAUDE.md")).then(press).then(open).then(draw)
    .expect(selected == Set("mf-both") and listed == Set("/t/web", "/t/api") and instructions == Set("/h/CLAUDE.md"))
  /// F13: web added, a click on mf-both prints the line of api alone.
  /// picked
  run pickTest = initWith(Set("/t/web"), Set()).then(press).then(open).then(draw).then(pick("mf-both"))
    .expect(addLines == Set("/t/api") and switchTo == "")
  /// F14: web added, a click on trade prints the trade line and the new-session command.
  /// picked
  run switchTest = initWith(Set("/t/web"), Set()).then(press).then(open).then(draw).then(pick("trade"))
    .expect(addLines == Set("/p/trade") and switchTo == "trade")
  /// F9: a press on the button of the instructions part shows it.
  /// shown
  run instructionsTest = initWith(Set(), Set("/h/CLAUDE.md")).then(press).then(open).then(draw)
    .then(toggleInstructions).expect(showInstructions)
  /// F1: a press on the open pane closes it.
  /// closed
  run closeTest = initWith(Set(), Set()).then(press).then(open).then(draw).then(press).then(close)
    .expect(phase == "closed" and not(isOpen))
}
