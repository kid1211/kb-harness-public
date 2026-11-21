# Graph colours

## Goal

A graph block can colour one node's text and fill, and one link's line and text, by palette name. Draft.

Route: poc

Builds: `.claude/lib/draw-graph/draw-graph.js`, `.claude/lib/draw-graph/tests/parse.test.js`, `.claude/skills/draw-graph/SKILL.md`
Uses: `.claude/lib/palette/` (the colour names and values), the graph check `.claude/lib/draw-graph/check.js`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's want, 2026-11-20: "allos coloring the text color or area color or the line color or the text near line color", with a screenshot of a graph whose nodes and links are all grey.

- **F1.** A graph can give one node its own text colour and its own fill colour.
- **F2.** A graph can give one link its own line colour and its own colour for the text on the line.
- **F3.** A colour is a name from the palette, such as `tan` or `light-blue`, never a hex value. A dark fill colour, such as `midnight` or `navy`, is for a node's fill only, since text and lines in it are too dark to read.
- **F4.** A colour name that is not in the palette, or a dark colour on text or a line, makes the graph show an error, so the graph check fails it. `firebrick` is not a choice: red is for errors only.
- **F5.** A node or link with no colour line looks as it does now. The colour of a node's kind, such as a component or a failure, gives way to the colour line.

- ✅ **R1. Node colours:** [implement] A line `color <node> text=<name> fill=<name>` gives one node its text colour, its fill colour, or both. They win over the colour of its kind.
- ✅ **R2. Link colours:** [implement] A line `color <a> -> <b> line=<name> label=<name>` gives each link from `a` to `b` its line and arrow colour, its text colour, or both. A loop takes no colour.
- ✅ **R3. Palette names only:** [implement] Text and labels take `tan`, `linen`, `light-blue` or `white`. A line also takes `slate-blue`. A fill also takes the dark fills `navy`, `midnight`, `charcoal`, `olive` and `fern`. No part takes `firebrick` or a hex value.
- ✅ **R4. A bad line is an error:** [implement] If a colour line names an unknown colour, part, node or link, or puts a dark colour on text or a line, the graph shows an error with the line number, and the graph check fails it.
- ✅ **R5. No line, no change:** [implement] A graph with no colour line draws as before, and the hover still dims and lights a coloured node or link.

## Open questions

None.

## Research questions

### User

None.

### Claude

None.
