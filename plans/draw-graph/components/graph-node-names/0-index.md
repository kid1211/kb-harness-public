# Graph node names

## Goal

A graph node name can be up to 6 words, joined by underscores, in place of one word only. Draft.

Route: poc

Builds: `.claude/lib/draw-graph/draw-graph.js` (the word cap of a node name), `.claude/lib/draw-graph/tests/parse.test.js` (the node name tests), `.claude/skills/draw-graph/SKILL.md` (the node name rule)
Uses: the graph check `.claude/lib/draw-graph/check.js`, which fails a graph on each warning of the parse

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's want, 2026-11-20: "lift this requirement, maybe max 6 words, that is it", on the rule that a node ID is one word.

- **F1.** A node name can be up to 6 words, joined by `_`. The page shows each `_` as a space, so `afu_health_answer` shows as "afu health answer".
- **F2.** A node name of 7 words or more draws, but the parse warns with the name and its word count, so the graph check fails the graph.
- **F3.** A graph whose node names have 6 words or fewer draws as before, with no warning.
- **F4.** `SKILL.md` says a node name is up to 6 words joined by `_`, in place of one word.

- ✅ **R1. Up to 6 words:** [implement] A node name has up to 6 words, its parts between `_`. The page shows each `_` as a space.
- ✅ **R2. Over the cap warns:** [implement] A node name of 7 words or more still draws. The parse warns once, with the name and its word count, so the graph check fails the graph.
- ✅ **R3. Within the cap, no change:** [implement] A graph whose node names have 6 words or fewer draws as before, with no warning.
- ✅ **R4. The rule in the skill:** [implement] `SKILL.md` of draw-graph says a node name is up to 6 words joined by `_`, with no spaces.

## Open questions

None.

## Research questions

### the user

None.

### Claude

None.
