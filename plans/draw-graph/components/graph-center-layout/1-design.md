# Graph center layout: design

## State transitions

The model is [graph-center-layout.qnt](graph-center-layout.qnt), module `graphCenterLayout`.

```graph
import-graph: architecture.md
```

1. [Read](#read): the library reads a graph block.
2. [Layered](#layered): no node has a `ring` line.
3. [Placing](#placing): a node has a `ring` line.
4. [Centered](#centered): the drawing passes the graph check.
5. [Broken](#broken): the drawing breaks a rule of the check.

## State deep dive

### Read

`parse` reads each line `ring <n> a b c`. It sets `ring: n` on each node it names. Ring 0 is the center.

**Invariants:** `noRingsLayered`.

**Expected output:** the parsed graph, with a `ring` number on each node of a ring line.

### Layered

No node has a ring. ELK lays the graph out, as before.

**Invariants:** `noRingsLayered`.

**Expected output:** the same drawing as before this change.

### Placing

`ringPlace` puts each node on a ring. A node with no ring line goes on the ring after the last one.

- `toLayered` goes to Layered when no node has a ring, and `toPlacing` comes here when one has.
- The radius of a node is `radius` of the model: the ring times the gap `STEP`, less a pull for its links. The pull stays under the gap, so the rings keep their order.
- Each ring is wide enough to hold its nodes side by side. A node gets more room on its ring for each link it has.
- A ring past the first sits nearer than a full `STEP`. Those rings hold few links, and a smaller graph keeps its text readable.
- Each node takes the mean angle of the nodes it links to, and stays as near it as it can. Two nodes of one ring move apart only as far as their width needs, so a node sits next to the nodes it links to. Only a ring too full for that shares the whole circle.
- A link is a straight line. If it crosses a node that is not its own, it bends around it. Two links between one pair bend to each side. If a side has no free bend, the link tries the other side.
- The text of each link sits on its line, at the first point where it covers no node, no other text and no other line. If its line has no such point, the line takes another bend.
- A link whose text finds no free point goes first in the next try, up to 6 tries.
- Each node is a dot, `dotSize` of the model across, with its name under it. The dot takes the text colour of its node. A link has no text on the line: `linkTextShown` shows it on hover of the link or one of its nodes. The text placing above then has no text to place, and only bends the lines.

**Invariants:** `ringsInOrder`, `moreLinksNearer`, `dotsGrow`.

**Expected output:** a position for each node, inner rings nearer the center.

### Centered

The graph check passes on the drawing, by `toCentered`. Else `toBroken` goes to Broken.

**Invariants:** `centeredIsClean`.

**Expected output:** no line from the graph check.

### Broken

The graph check names each rule the drawing breaks. The kb-design page then fails, as it does for a broken ELK drawing.

The run stays here, by `stay`.

**Expected output:** one line for each broken rule.

## Build checks

- Unit tests in `.claude/lib/draw-graph/tests/parse.test.js`:
  - `noRingsLayered`: the `ring` line sets the ring of each node it names, and a graph with none has no ring,
  - `ringsInOrder`: in `ringPlace`, an inner ring sits nearer the center than an outer one,
  - `moreLinksNearer`: in `ringPlace`, more links sit nearer inside one ring,
  - `ringPlace`: no two node boxes overlap.
  - `dotsGrow` and `linkTextShown`: a graph with rings has dot nodes, bigger with more links, and its links hold their text for hover only.
- `centeredIsClean`: the graph check on the food data model page, `personal/food/kb-model.staging.md`, drawn with rings.
- The negative control `neverBroken` fails, so the model checker can find a broken drawing.
- No check can see whether the picture reads well. the user judges it.

## Coverage

| Want | Holds it |
|---|---|
| F1 | `radius`, `ringsInOrder`, `noRingsLayered`, `layeredTest`, and the ring tests of `parse.test.js` |
| F2 | `radius`, `moreLinksNearer`, `radiusTest`, and the `ringPlace` tests of `parse.test.js` |
| F3 | `centeredIsClean`, `centeredTest`, `brokenTest`, and the graph check on the food page |
| F4 | `linkTextShown`, `dotSize`, `dotsGrow`, `dotTest`, and the dot test of `parse.test.js` |
| layered | `layeredTest` |
| centered | `centeredTest` |
| broken | `brokenTest` |

## Risks

- A dense graph has many links through the middle, so their text can pile up. The text moves along its line to a free point, and the check fails the page if none is free.
- A wide graph shrinks to fit, so its text can get too small. The rings stay as tight as their nodes allow.
- The center layout ignores groups and the transpose button. A graph with rings has no use for either now.

## Appendix

- The prototype of 2026-11-22: Cytoscape's force layout, then each node pushed out to its ring. Clusters stayed together, but boxes and text piled up. `ringPlace` keeps the idea and adds the spread and the text placing.
