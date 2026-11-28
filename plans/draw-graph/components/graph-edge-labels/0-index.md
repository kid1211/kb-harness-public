# Graph edge labels

## Goal

A link's text sits inside the line itself: the line breaks and the text fills the gap, not beside it. The text wraps past a max width, about the width of get-grocery-list. Draft.

Route: poc

Builds: `.claude/lib/draw-graph/draw-graph.js` (where a link's text sits, and its wrap), `.claude/lib/draw-graph/tests/check.test.js` (the link text tests), `.claude/skills/draw-graph/SKILL.md` (the link text rule)
Uses: ELK's inline edge labels (`elk.edgeLabels.inline`), the graph check `.claude/lib/draw-graph/check.js`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's want, 2026-11-21: "the name of the lin can it be in the line itself? and just break the line and insert he name instead of on teh side, and it should have a max width once it reach the ndo word wrap", with a picture of the text "get-grocery-list" as about the max width.

- **F1.** A link's text sits on the line itself, at a point along it, not beside it.
- **F2.** The line breaks at the text: the text has a gap around it, in the page's background colour, so no line runs through or under it.
- **F3.** A link's text has a max width, about the width of "get-grocery-list" in the link font. Longer text wraps word by word onto more lines.
- **F4.** The layout leaves room for the wrapped text, so the graph check finds no new overlap or crossing on the graphs that pass now.
- **F5.** A line `about [text]: note` gives each link with that text a note. A hover on the link shows the note, one line per `about` line, in order. *(the user, 2026-11-21: "show key feature or the description of the skill when hover the text in the line, exampl ... 1. ocr turn body scale to xxx 2. invoke afu to update the target")*

- ✅ **R1. In the line:** [implement] A link's text sits on its link: its centre is on the link's route, at the place ELK left room for it.
- ✅ **R2. A gap in the line:** [implement] The text has the page background behind it, with padding, so the link looks broken around it.
- ✅ **R3. Wrap past the max width:** [implement] A link's text wraps word by word at the width of "get-grocery-list" in the link font. ELK gets the size of the wrapped text.
- ✅ **R4. No new overlap:** [implement] The graph check finds no new overlap or crossing on the graphs of the harness and `personal`. Graphs with long link text grow taller, and more of them break the ratio rule. the user accepted that.
- ✅ **R5. The rule in the skill:** [implement] `SKILL.md` of draw-graph says a link's text sits in the line and wraps past the width of `get-grocery-list`.

## Open questions

None.

## Research questions

### the user

None.

### Claude

None.
