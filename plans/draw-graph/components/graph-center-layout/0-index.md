# Graph center layout

## Goal

A graph can be drawn around a center. Each node sits on a ring, and the inner rings hold the most important kinds of node. The kb-design page uses it to put index types in the middle, then staging, then raw, then external nodes.

Route: poc

Builds: `.claude/lib/draw-graph/draw-graph.js` (the `ring` line and the center layout), `.claude/lib/draw-graph/tests/parse.test.js` (the ring tests), `.claude/skills/draw-graph/SKILL.md` (the `ring` row)
Uses: the graph check `.claude/lib/draw-graph/check.js`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

the user's words, 2026-11-22, on the data model page of a domain: "can you update the data model graph skill, where index is closer to the graph center, and then staging then raw. Then complete external, like the more center the closer, because it likely more important and have more connection".

- **F1.** A graph can put each node on a ring around a center. Ring 0 is the center, and each next ring sits further out. A graph with no ring line keeps its left-to-right or top-to-bottom layout.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: index in the middle, then staging, then raw, then external at the edge.
- **F2.** Inside one ring, a node with more links sits nearer the center, and a node sits near the nodes it links to.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: meal, with the most links, sits closest to the middle.
- **F3.** A graph in the center layout still passes the graph check: no text covers other text, and no link crosses a node that is not its own.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: the picture is as clean as the left-to-right one, with no pile of boxes or labels.
- **F4.** A graph in the center layout draws each node as a round dot with its name under it, like Obsidian's graph view. A dot with more links is bigger. The text of a link shows only when the mouse is on the link or one of its nodes.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: "Round dots like Obsidian", picked 2026-11-22: less crowded than boxes with text on every link. The rings keep their order, raw further out than staging.

## Open questions

TBD

## Research questions

### the user

TBD

### Claude

TBD
