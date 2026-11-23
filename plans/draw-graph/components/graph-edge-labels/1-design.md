# Graph edge labels: design

## State transitions

The model is [graph-edge-labels.qnt](graph-edge-labels.qnt).

```graph
import-graph: architecture.md
```

1. Read: the library reads the text of one link. See [read](#read).
2. One line: the text is as wide as the max width or less. See [one_line](#one_line).
3. Wrapped: the text is wider than the max width. See [wrapped](#wrapped).

## State deep dive

The max width is `EDGE_WRAP` in `draw-graph.js`: the measured width of "get-grocery-list" in the link font. The model counts it as `MAX_CHARS`, 16 characters.

### read

`initWith` starts here. `layout` gives ELK each link's text with its size after the wrap, and sets `elk.edgeLabels.inline`, so ELK puts the text on the link and leaves room for it.

**Invariants:** none.

**Expected output:** none.

### one_line

The text sits at the point ELK chose on the link. Its background is the page background, with padding, so the link looks broken around the text.

**Invariants:** `inTheLine`, `widthCapped`, `wrapOnlyWhenWide`, `roomForText`.

**Expected output:** one line of text, its centre on the link.

### wrapped

As one_line, with `text-wrap: wrap` and `text-max-width: EDGE_WRAP`. The size given to ELK is the wrapped size: the widest line by the width, and the number of lines by the line height.

**Invariants:** `inTheLine`, `widthCapped`, `wrapOnlyWhenWide`, `roomForText`.

`done` keeps the run at one_line or wrapped.

**Expected output:** two or more lines, none wider than `EDGE_WRAP`, centred on the link.

## Build checks

- `node --test .claude/lib/draw-graph/tests/check.test.js`, two new tests:
  - a short link text: its label box holds a point of its link, so it is on the line (`inTheLine`, `shortTextTest`);
  - a long link text: its label box is no wider than `EDGE_WRAP` plus padding and taller than one line, and the graph check prints nothing (`widthCapped`, `roomForText`, `wrapTest`).
- `npm run check`: the runs of the model. `quint run` holds `inTheLine`, `widthCapped`, `wrapOnlyWhenWide` and `roomForText`. The negative control `neverWrapped` must fail.
- The other tests of `check.test.js` pass, so the change adds no overlap or crossing.
- The F4 check: run `node .claude/lib/draw-graph/check.js` on each page with a `graph` block in the harness and `personal`. Run it with the `draw-graph.js` of `main` and of the branch. The branch must not have more overlaps and crossings.
- No check can see the gap in the line in VS Code's preview. The user judges that by eye.
- `SKILL.md` of draw-graph is knowledge, not states, so no `C flow` heading applies. Its line on `b [text]` says the text sits in the line and wraps past about 16 characters.

## Coverage

| Want | Held by |
|---|---|
| F1 | `oneLine`, `inTheLine`, `shortTextTest`, `check.test.js` "a link's text sits on its link" |
| F2 | `inTheLine`, `shortTextTest`. The gap itself: by eye only |
| F3 | `wrap`, `widthCapped`, `wrapOnlyWhenWide`, `maxWidthTest`, `wrapTest`, `shortNoWrapTest`, `check.test.js` "a long link text wraps" |
| F5 | `note`, `aboutTest`, and the about test of `parse.test.js`. The hover itself: by eye and the Chromium check |
| F4 | `roomForText`, `wrapTest`, `check.test.js` "a long link text wraps" and the other tests of `check.test.js` |
| R1 | `oneLine`, `inTheLine`, `shortTextTest`, `check.test.js` "graph-edge-labels inTheLine" |
| R2 | `inTheLine`. The gap itself: by eye only |
| R3 | `wrap`, `widthCapped`, `wrapOnlyWhenWide`, `wrapTest`, `check.test.js` "graph-edge-labels widthCapped, roomForText" |
| R4 | `roomForText`, and the sweep of each graph page of the harness and `personal` against `main` |
| R5 | not in the model: a line of `SKILL.md`, checked by reading it |
| one_line | `shortTextTest` |
| wrapped | `wrapTest` |

## Risks

- **ELK puts inline text on the first segment of a link, not its middle.** It still sits on the line, which is what the user asked. If it looks odd, a later round can move it with `elk.edgeLabels.placement`.
- **A text on the line makes the gap between layers wider.** Graphs grow a little. The graph check still fails one that gets too tall or wide.
- **The measured width in the page differs from Cytoscape's wrap.** Both use the same font and `EDGE_WRAP`, so ELK gets the size Cytoscape draws.

## Appendix

- ELK option `org.eclipse.elk.edgeLabels.inline`: "If true, an edge label is placed directly on its edge." ELK reference, layered algorithm.
- the user's picture, 2026-11-21: the text "get-grocery-list" as about the max width.
