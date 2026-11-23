# Graph filter: design

## State transitions

The model is [graph-filter.qnt](graph-filter.qnt), module `graphFilter`.

```graph
import-graph: architecture.md
```

1. [Read](#read): the library reads a graph block.
2. [Plain](#plain): the block holds no `filter` line.
3. [Filtering](#filtering): the block holds a `filter` line.

## State deep dive

### Read

`parse` reads each line. A line that is only `filter` sets `filter: true` on the parsed graph.

A line `label a: text` sets the label of node `a` to `text`, so the node and its filter button show `text`. Its ID stays `a`, so two nodes can show one name.

**Expected output:** the parsed graph, with `filter` true or false.

### Plain

`draw` adds no button row. The graph is as before.

**Invariants:** `plainShowsAll`, `buttonsFit`.

**Expected output:** no `.dg-filter` element.

### Filtering

`draw` adds a `.dg-filter` row under the graph: an All button, a None button, then one button per node, in the order of its first line, with the node's label. Each node button starts on.

- A click on a node button turns it off and hides the node, or on and shows it. Cytoscape hides each link of a hidden node.
- All turns each button on, None turns each one off. After each click the graph fits its shown nodes.
- A button shows its full label on one line.
- A node button selects or clears its node. The graph shows the selected nodes.
- A plain node wraps its name, word by word, at the width of "raw recipe source" in the node font. A node with one line keeps its height. A state box, a decision and a node with an icon keep their own sizes.
- The row wraps onto more lines, a long label wraps inside its button, and the row has a padding of 12% of its width on each side.
- An off button has a dim colour. The colours come from the `--dg-*` properties of the page.

**Invariants:** `buttonsFit`, `noLooseLink`.

**Expected output:** one button per node, and the graph showing only the nodes whose button is on.

## Build checks

- **Unit tests** in `.claude/lib/draw-graph/tests/parse.test.js`: a `filter` line sets `filter: true` (Read), no `filter` line leaves it false (`plainShowsAll`), and a `filter` line adds no node or link (`buttonsFit`).
- A unit test: a `label` line sets the label of its node, keeps its ID, and adds no node.
- `noLooseLink` holds by Cytoscape: a hidden node hides its links. No unit test sees the DOM, so the user checks the row in the preview, with its wrap and padding.
- The negative control `neverHidden` fails on purpose.

## Coverage

| Want | Held by |
|---|---|
| F1 | `toFiltering`, `click`, `allOrNone`, `stay`, `links`, `buttonsFit`, `noLooseLink`, `filteringTest`, the negative control `neverHidden` |
| F2 | the user, in the preview: no state holds the look of the row |
| F4 | `display`, `labelTest`, the label unit test |
| F5 | changed into F6 |
| F6 | the user, in the preview, and the graph check of each plan graph |
| F3 | `toPlain`, `plainShowsAll`, `plainTest` |
| filtering | `filteringTest` |
| plain | `plainTest` |

## Risks

- **A hidden node keeps its place.** The layout is not run again, so the shown nodes keep where they were, and the graph fits them. If the gaps look odd, a later round can run the layout on the shown nodes.
- **The graph check sees all nodes.** `check.js` draws each graph with every node on, so a filter line changes no rule.

## Appendix

- the user's words of F1 and F2 are in `0-index.md`.
- The flip and reset buttons of `draw` are the form the new buttons follow.
