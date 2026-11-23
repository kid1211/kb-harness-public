# Graph filter

## Goal

A list of the nodes of a graph, under the graph, where the user ticks which nodes to show. He can look at a few nodes and how they relate, then add more and build up.

Route: poc

Builds: `.claude/lib/draw-graph/draw-graph.js` (the `filter` line and the button row), `.claude/lib/draw-graph/tests/parse.test.js` (the filter tests), `.claude/skills/draw-graph/SKILL.md` (the `filter` row)
Uses: the palette `.claude/lib/palette/`, the graph check `.claude/lib/draw-graph/check.js`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

the user's words, 2026-11-20, on the data model page of a domain: "can we have list of topic or model to show/hide? maybe at the bottom to select and filter or something? like i want to see couple one how they relay and slowly build up".

- **F1.** Under a graph, a list of its nodes lets the user tick which ones to show. The graph then shows only those nodes and the links between them.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I start with two or three types, see how they relate, then tick more to build up.
- **F2.** The list is a row of buttons under the graph, one per node. The row wraps onto more lines, a long name wraps inside its button, and the row keeps 10 to 15% of the width free on each side. *(the user, 2026-11-20: "it should be prob mutlipel row, and do the word warp, and give like 10-15% each side of padding")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: the buttons sit in a tidy block under the graph, not one long line.
- **F3.** A graph gets the row only when its text holds a `filter` line, so the other graphs stay as they are.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: only the pages where I want to build up get the buttons.
- **F4.** A `label a: text` line gives node `a` a display name apart from its ID. The node and its filter button show the display name, so two nodes can show one name. *(the user, 2026-11-20: "it is allow to have raw and staiging have the same name, but the identifier should automatically add staging/xxx raw/xxx ... it just in the fodler name no need to have the raw-x and staging- ... when it is shown in the identifier it should have the prefix and the display name should not have those, and the graph should use the display name, but also color accordingly, for al lthe model")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: two nodes named "recipe" can sit on one graph.
- **F5.** A filter button holds at most 3 words per line, so a long name wraps sooner, near the width of "raw recipe source". *(the user, 2026-11-21: "each button should have 3 words max per row so it should word wrap faster", "this is likley the max width")*
  Decision: changed
  Built: 0 of 0
  What Claude thinks the user means: Claude read "button" as a filter button. the user meant a node of the graph: F6.
- **F6.** A node of the graph wraps its name, word by word, at the width of "raw recipe source", so a long name takes two lines in place of a wide box. A filter button shows its full name on one line. *(the user, 2026-11-21: "this didn 't respect the max width rule to do word wrap, ( the rule was not max width for the text i jsut want you to word wrap", "bottom can show the full button")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: "inventory inferred quantity" in the graph sits on two lines, and its button below stays on one.
- **F7.** The row has a depth toggle of -1, 0 and +1, 0 by default. At 0 the graph shows only the selected nodes. At +1 it also shows the nodes one link down from them, and at -1 the nodes one link up. *(the user, 2026-11-21: "when selected, (it should incldue 1 up and 1 down (or there should be a toggle to say show depth, if the toggle is 0, which is default, that means only show th selected node, if it is 1 than show 1 down and if neagtive 1 the n1 up, only 0 -1, +1")*
  Decision: dropped *(the user, 2026-11-21: "remvoe this , and its feature and so on they are not useful")*
  Built: 0 of 0
  What Claude thinks the user means: I pick "body reading" and set +1: I see body reading and member needs. At -1 I see body reading and body scale reading.
- **F8.** -1 and +1 are two toggles that can be on at once. With both on, the graph shows the nodes one link up and one link down. 0 turns both off. *(the user, 2026-11-21: "so -1 and +1 can be multi select")*
  Decision: dropped *(the user, 2026-11-21: "remvoe this , and its feature and so on they are not useful")*
  Built: 0 of 0
  What Claude thinks the user means: I pick member needs, turn on -1 and +1, and see what feeds it and what it feeds.

## Open questions

TBD

## Research questions

### the user

TBD

### Claude

TBD
