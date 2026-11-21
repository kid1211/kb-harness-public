# Graph colours: design

## State transitions

The model is [graph-colours.qnt](graph-colours.qnt).

```graph
import-graph: architecture.md
```

1. Read: the library reads one line of a graph block. See [read](#read).
2. Plain: the line is not a colour line. See [plain](#plain).
3. Applied: a colour line with palette names that fit their parts. See [applied](#applied).
4. Error: a colour line with a name that is not in the palette, firebrick, or a dark colour on text or a line. See [error](#error).

## State deep dive

Two new line forms in a graph block, parsed by `parse` in `.claude/lib/draw-graph/draw-graph.js`:

- `color <node> text=<name> fill=<name>`: a node. Either key can stand alone.
- `color <a> -> <b> line=<name> label=<name>`: each link from `a` to `b`. Either key can stand alone.

| Part | Colours that fit |
|---|---|
| `text`, `label` | `tan`, `linen`, `light-blue`, `white` |
| `line` | the four above, and `slate-blue` |
| `fill` | the five above, and `navy`, `midnight`, `charcoal`, `olive`, `fern` |

The model holds the table as `LIGHT`, `LINE_ONLY`, `DARK` and `fits`. `firebrick` fits no part. The values come from `.claude/lib/palette/palette.css`.

### read

`initWith` starts here. `parse` reads each line. A line that starts with `color ` is a colour line.

**Invariants:** none.

**Expected output:** none.

### plain

Each node and link keeps the colour of its kind: step, component, start, end, failure, skill or hook.

**Invariants:** `plainKeepsKind`.

**Expected output:** the graph drawn as before this change.

### applied

The node gets a `color`, `background-color` or both. The link gets a `line-color` with the same arrow colour, a label `color`, or both. These styles go on the element itself, so they win over the style of its kind.

**Invariants:** `shownFits`, `noRedNoUnknown`.

**Expected output:** the parsed graph holds `colors` on the node or link. The drawn graph shows them.

### error

`parse` throws an error that names the line and the bad name. The page shows the error box in place of the graph, as for any other bad line, so `check.js` fails the graph.

**Invariants:** `badIsError`, `noRedNoUnknown`.

`done` keeps the run at plain, applied or error.

**Expected output:** an `Error` with the line number and the colour name.

## Build checks

- `node --test .claude/lib/draw-graph/tests/parse.test.js`: one test per `run` of the model. A node gets text and fill, a link gets line and label, a dark colour on text throws, firebrick throws, a hex value throws, a graph with no colour line parses as before.
- `npm run check`: the runs of the model. `quint run` holds `shownFits`, `noRedNoUnknown`, `badIsError` and `plainKeepsKind`. The negative control `neverApplied` must fail.
- The other suites of the library still pass: `check.test.js`, `import-graph.test.js`.
- No check can see the colours in VS Code's preview. The user judges that by eye.
- `SKILL.md` of draw-graph is knowledge, not states (`draw-graph` R12). It gets the two line forms and the table, so no `C flow` heading applies.

## Coverage

| Want | Held by |
|---|---|
| F1 | `apply`, `nodeTextTest`, `nodeFillTest` |
| F2 | `apply`, `linkLineTest`, `linkLabelTest` |
| F3 | `fits`, `shownFits`, `darkTextTest` |
| F4 | `refuse`, `badIsError`, `noRedNoUnknown`, `firebrickTest`, `hexTest` |
| F5 | `plain`, `plainKeepsKind`, `plainTest` |
| R1 | `apply`, `nodeTextTest`, `nodeFillTest`, `parse.test.js` "a colour line gives a node its text and fill" |
| R2 | `apply`, `linkLineTest`, `linkLabelTest`, `parse.test.js`. The loop error is in the code only, since the model has no link ends |
| R3 | `fits`, `shownFits`, `darkTextTest`, `hexTest`, `firebrickTest` |
| R4 | `refuse`, `badIsError`, `noRedNoUnknown`, `parse.test.js` "a bad colour line throws". The line number and an unknown node are in the code only |
| R5 | `plain`, `plainKeepsKind`, `plainTest`. The hover is checked by eye only |
| plain | `plainTest` |
| applied | `nodeTextTest` |
| error | `darkTextTest` |

## Risks

- **A colour line names a node or link that does not exist.** The model does not cover it. `parse` throws, as for a bad name, so the graph check catches a typo.
- **Light fill with the default light text.** A `tan` fill under light text is hard to read. The design allows it, since the user can set `text` on the same line. The PoC shows whether this needs a rule.
- **Hover dimming.** The hover style dims other nodes. A set colour must still dim. The build keeps the opacity rule apart from colour.
- **The palette changes.** The names are a table in `draw-graph.js` with the values of `palette.css`. A new palette colour needs a new row.

## Appendix

- The palette and its rule that dark colours are fills only: `.claude/lib/palette/README.md`.
- The colours of each kind today: `--dg-*` in `vscode-draw-graph/preview.css`.
- The user's screenshot, 2026-11-20: a food graph whose nodes and links are all grey.
