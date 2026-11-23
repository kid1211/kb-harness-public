```graph
begin read
end layered centered
fail broken
external parse draw check
parse: The parse function of .claude/lib/draw-graph/draw-graph.js
draw: The layout function of .claude/lib/draw-graph/draw-graph.js
check: The graph check, .claude/lib/draw-graph/check.js
read: The library reads the lines of a graph block, with each ring line.
read.run: parse
rings?: Does a node have a ring line?
layered: No ring line. ELK lays the graph out left to right or top to bottom, as before.
layered.run: draw
placing: Each node goes on its ring, near the nodes it links to, the ones with more links nearer the center.
placing.run: draw
clean?: Does the drawing pass the graph check?
centered: The graph is drawn around its center.
centered.run: check
broken: The check names each rule the drawing breaks.
broken.run: check
read -> rings?
rings? -> layered [no], placing [yes]
placing -> clean?
clean? -> centered [yes], broken [no]
```
