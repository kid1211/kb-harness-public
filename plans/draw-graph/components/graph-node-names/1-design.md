# Graph node names: design

## State transitions

The model is [graph-node-names.qnt](graph-node-names.qnt).

```graph
import-graph: architecture.md
```

1. Read: the library reads one node name. See [read](#read).
2. Plain: the name has 6 words or fewer. See [plain](#plain).
3. Warned: the name has 7 words or more. See [warned](#warned).

## State deep dive

A node name is its ID. The words of a name are its parts between `_`, so `afu_health_answer` has 3 words. The cap is `MAX_WORDS`, 6. A name still holds no space, since each line form splits on spaces.

### read

`initWith` starts here. `parse` in `.claude/lib/draw-graph/draw-graph.js` makes the node the first time a line names it.

**Invariants:** none.

**Expected output:** none.

### plain

The node draws with each `_` shown as a space. No warning.

**Invariants:** `withinCapIsPlain`, `warnOnlyOverCap`, `alwaysDrawn`.

**Expected output:** the parsed graph holds the node, and no warning names it.

### warned

The node draws as in plain. `parse` also calls `console.warn` once, with the name and its word count. `check.js` counts each warning as a broken rule, so the graph check fails the graph.

**Invariants:** `warnOnlyOverCap`, `alwaysDrawn`.

`done` keeps the run at plain or warned.

**Expected output:** one warning `draw-graph: node name <id> has <n> words, keep it to 6`.

## Build checks

- `node --test .claude/lib/draw-graph/tests/parse.test.js`: one test per `run` of the model. One word and six words parse with no warning, seven words parse and warn once, and the node is still in the graph.
- `npm run check`: the runs of the model. `quint run` holds `warnOnlyOverCap`, `alwaysDrawn` and `withinCapIsPlain`. The negative control `neverWarned` must fail.
- The other suites of the library still pass: `check.test.js`, `import-graph.test.js`.
- A sweep of every `graph` block in the harness and `personal`: no node name has more than 6 words, so no page fails after the change.
- No check can see a long name in VS Code's preview. The user judges that by eye.
- `SKILL.md` of draw-graph is knowledge, not states (`draw-graph` R12), so no `C flow` heading applies. Its rule line says up to 6 words joined by `_`.

## Coverage

| Want | Held by |
|---|---|
| F1 | `plain`, `withinCapIsPlain`, `oneWordTest`, `sixWordsTest` |
| F2 | `warn`, `warnOnlyOverCap`, `alwaysDrawn`, `sevenWordsTest`, `sixWordsNoWarnTest` (a model run only) |
| F3 | `plain`, `warnOnlyOverCap`, `sixWordsTest` |
| F4 | not in the model: a line of `SKILL.md`, checked by reading it |
| R1 | `plain`, `withinCapIsPlain`, `oneWordTest`, `sixWordsTest`, `parse.test.js` "a node name of 1 to 6 words parses with no warning" |
| R2 | `warn`, `warnOnlyOverCap`, `alwaysDrawn`, `sevenWordsTest`, `parse.test.js` "a node name of 7 words still draws, and warns once" |
| R3 | `warnOnlyOverCap`, `withinCapIsPlain`, `sixWordsTest`, and the sweep of each `graph` block |
| R4 | not in the model: a line of `SKILL.md`, checked by reading it |
| plain | `oneWordTest` |
| warned | `sevenWordsTest` |

## Risks

- **A space in a name.** the user may read "words" as words with spaces. Each line form splits on spaces, so a space would change every line form. The design keeps `_` and says so in `SKILL.md`.
- **A long name makes a wide node.** A plain node does not wrap. Six words is about 40 characters, which fits the 1050 px box. The graph check still fails a graph that does not fit.
- **An old page over the cap.** The sweep before the build finds it.

## Appendix

- The rule before this change: `SKILL.md` of draw-graph, "A node ID is one word with no spaces".
- The user's screenshot, 2026-11-20: a table of food graph node names, each 1 to 3 words.
