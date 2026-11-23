---
name: draw-graph
description: Draw a graph — a flowchart, a component relationship graph, or a hierarchy — as a ```graph block inside a markdown page, in place of Mermaid. A few lines of short text; VS Code's preview draws it with Cytoscape.js and an ELK layout, with hover, zoom, pan, group boxes and text on links.
when_to_use: Use for every graph written into a file - "draw the architecture", "graph how these components connect", "make a flowchart of this", "map the dependencies", a plan's component graph, or any time Mermaid comes to mind. Never write a ```mermaid block; a hook refuses it. Also use to edit an existing ```graph block.
user-invocable: true
---

# Drawing a graph

A graph is a ```` ```graph ```` block in a markdown page, where Mermaid
would have gone. Never write Mermaid: a hook refuses a ```` ```mermaid ````
block in any `.md` file.

## The graph text

````
```graph
# a comment
[Backend] api worker
[Data] db cache
api: Serves the public REST API
web -> api [calls]
api -> db [reads and writes], cache
worker -> db
```
````

| Line | Means |
|---|---|
| `a -> b, c` | links from `a` to `b` and to `c`. A node needs no other line. |
| `b [text]` | after a target: the text on that link. It sits in the line, which breaks around it, and wraps past the width of `get-grocery-list` |
| `a: text` | the description shown when the mouse is on `a`. Each more `a:` line adds a line, such as a `- ` bullet |
| `about [text]: note` | a note shown when the mouse is on a link whose text is `text`. Several lines for one text show in order |
| `a.run: text` | makes `a` a state box: its name, a `----` rule, `run: [...]` the components that do the work, then `in: [...]` and `out: [...]`, the components of the nodes its links come in from and go out to: each node's `run`, or its name. An ID may hold a colon, as `spec:check?`, so a hover line needs a space after its colon. Its `a: text` stays the hover |
| `a -> a [text]` | a loop inside `a`: an arrow out of its right side to the text, and back in. The text says what the loop does |
| `[Group] a b` | puts `a` and `b` in a box named Group |
| `begin a` | `a` is where the flow starts: a slate-blue pill with a power icon |
| `end a b` | `a` and `b` are where the flow ends well: green pills with a flag icon |
| `fail a` | `a` is where the flow stops on a failure: a red pill with a circled cross |
| `skill a` | `a` is a skill: a light blue border and a box icon |
| `hook a` | `a` is a hook, which plugs into an event: a tan border and a plug icon |
| `external a b` | `a` and `b` are components of another kind, such as a tool or a plan's component. A link to or from a node on an `external`, `skill` or `hook` line is dotted |
| `color a text=tan fill=midnight` | gives `a` its own text colour, fill colour, or both. They win over the colour of its kind |
| `color a -> b line=tan label=linen` | gives each link from `a` to `b` its own line colour, text colour, or both |
| `label a: text` | the node `a` and its filter button show `text` in place of its ID, so two nodes can show one name |
| `filter` | a row of buttons under the graph, one per node, with All and None: a click selects or clears that node. |
| `ring 0 a b` | draws the graph around a center: `a` and `b` on ring 0, the middle. A higher number is further out. A node with more links sits nearer the middle, and a node with no ring line goes outside the last ring. Each node is then a dot with its name under it, bigger with more links, and a link's text shows only on hover |
| `# text` | a comment |

A colour is a palette name, not a hex value. If a name, part or node is
not in the table or the graph, the graph shows an error, and the check fails it.

| Part | Names |
|---|---|
| `text`, `label` | `tan`, `linen`, `light-blue`, `white` |
| `line` | those, and `slate-blue` |
| `fill` | those, and the dark fills `navy`, `midnight`, `charcoal`, `olive`, `fern` |

`firebrick` is for errors only, so no colour line can use it.

- A node ID is up to 6 words joined by `_`, with no spaces. The page shows
  `_` as a space, so `grocery_receipt` shows as "grocery receipt". A name of
  7 words or more makes the graph check fail.
- Put all links from one node on one line.
- The layout flows left to right, in the order the link lines first name
  the nodes. Write links in flow order. A link back is drawn as a loop.
- Use groups only when the graph needs them. A group name must differ from
  every node ID, or the graph is blank.
- Keep a description to one sentence. Put the detail in the page's prose.
- A node whose ID ends with `?`, such as `fits?`, is a decision, drawn as
  a diamond. Give each link out its answer, such as [yes] and [no].
- A flowchart has one `begin` node. Each node where the flow stops goes on
  an `end` line if it went well, or a `fail` line if it did not. There are no other node shapes, and no other dotted or dashed links.
- ELK places every node and box, so the text holds no positions.

To show one graph on two pages, put it in its own `.md` file, such as
`architecture.md`, and import it. The file must be one graph block and
nothing else: the first line ```` ```graph ````, the last line ```` ``` ````. On each page:

````
```graph
import-graph: architecture.md
```
````

The path is relative to the page. Edit the graph only in the imported file.

## The check

After a write to a `.md` file with a graph block, a hook draws each graph
the way the viewer does, top to bottom, and names every rule it breaks:

| Rule | Means |
|---|---|
| R2 overlap | text covers other text: a node, a link's text or a group name |
| R2 crossing | a link crosses a node, text or a group name that is not its own |
| R3 ratio | a graph that has to shrink is more than twice as wide as tall, or as tall as wide |
| R4 density | at the size shown, text is under 9 px |

Fix the graph text: list links in a different order, shorten link text,
drop a group, or split the graph in two. To check by hand, run
`node .claude/lib/draw-graph/check.js <file.md>`.

## Where it is drawn

- VS Code's own Markdown preview draws each block in place, if the
  `vscode-draw-graph` extension is installed (`vscode-draw-graph/build.sh`).
  It draws an import too.
- GitHub and other markdown viewers show the block as text. The text is short
  enough to read there.

## Reference

- `.claude/lib/draw-graph/draw-graph.js` — the parser and the drawing code.
- `.claude/lib/draw-graph/import-graph.js` — reads an `import-graph:` block, for the preview and the check.
  Any HTML page can load it; its header says how. Cytoscape.js 3.34.3 and
  elkjs 0.12.0 load from a CDN, so a page needs the internet.
- `hooks/no-mermaid.sh` — the hook that refuses Mermaid.
- `hooks/check-graph.sh` and `.claude/lib/draw-graph/check.js` — the check.
- `plans/draw-graph/` — the requirements, and why these libraries. The
  check's rules are its `components/graph-check/`.
