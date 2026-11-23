// The graph filter: a row of buttons under a graph with a filter line, one per node. A click hides
// or shows a node, and a link shows only when both its nodes show.
// Not covered: the look of the row (wrap, padding), which the user judges in the preview.
// NEGATIVE CONTROL: neverHidden is false on purpose.
module graphFilter {
  pure val NODES: Set[str] = Set("a", "b", "c")
  pure val EDGES: Set[(str, str)] = Set(("a", "b"), ("b", "c"))

  var phase: str
  var shown: Set[str]
  var buttons: Set[str]

  /// F3: a graph with no filter line gets no button row.
  action toPlain = all { phase == "read", phase' = "plain", shown' = NODES, buttons' = Set() }
  /// F1: a graph with a filter line gets one button per node, each on.
  action toFiltering = all { phase == "read", phase' = "filtering", shown' = NODES, buttons' = NODES }
  /// F1: a click on a node button hides or shows that node.
  action click(n: str): bool = all { phase == "filtering", buttons.contains(n), phase' = phase, buttons' = buttons,
    shown' = if (shown.contains(n)) shown.exclude(Set(n)) else shown.union(Set(n)) }
  /// F1: All shows each node, None hides each one.
  action allOrNone(on: bool): bool = all { phase == "filtering", phase' = phase, buttons' = buttons, shown' = if (on) NODES else Set() }
  /// F1: an end state stays.
  action stay = all { phase' = phase, shown' = shown, buttons' = buttons }

  action init = all { phase' = "read", shown' = NODES, buttons' = Set() }
  action step = any { toPlain, toFiltering, nondet n = NODES.oneOf() click(n), nondet on = Set(true, false).oneOf() allOrNone(on),
    all { phase == "plain", stay } }

  /// F1: the links that show are those whose two nodes show.
  pure def links(s: Set[str]): Set[(str, str)] = EDGES.filter(e => s.contains(e._1) and s.contains(e._2))

  /// F1: one button per node, or none.
  val buttonsFit = buttons == Set() or buttons == NODES
  /// F3: a plain graph shows each node and no button.
  val plainShowsAll = phase == "plain" implies (shown == NODES and buttons == Set())
  /// F1: a link never shows with a hidden end.
  val noLooseLink = links(shown).forall(e => shown.contains(e._1) and shown.contains(e._2))
  /// NEGATIVE CONTROL: false on purpose, a node gets hidden.
  val neverHidden = shown == NODES

  /// F4: a label line gives a node its display name. With none, the node shows its ID.
  pure def display(id: str, labels: str -> str): str = if (labels.keys().contains(id)) labels.get(id) else id
  /// F4: two nodes can show one name, and each keeps its own ID and button.
  run labelTest = all { assert(display("raw_recipe", Map("raw_recipe" -> "recipe", "staging_recipe" -> "recipe")) ==
    display("staging_recipe", Map("raw_recipe" -> "recipe", "staging_recipe" -> "recipe")) and display("c", Map()) == "c"), init }

  /// filtering
  /// F1: hide a, then b, then show a: only a and c show, and no link.
  run filteringTest = init.then(toFiltering).then(click("a")).then(click("b")).then(click("a"))
    .then(all { assert(shown == Set("a", "c") and links(shown) == Set()), stay })
  /// plain
  /// F3: no filter line, no buttons.
  run plainTest = init.then(toPlain).then(all { assert(buttons == Set()), stay })
}
