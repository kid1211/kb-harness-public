```graph
begin read
end plain filtering
external parse draw
parse: The parse function of .claude/lib/draw-graph/draw-graph.js
draw: The draw function of .claude/lib/draw-graph/draw-graph.js, which makes the buttons
read: The library reads the lines of a graph block.
read.run: parse
filter?: Does the graph hold a filter line?
plain: No filter line. The graph shows no button row, as before.
plain.run: draw
filtering: One button per node under the graph. A click hides or shows that node and its links.
filtering.run: draw
read -> filter?
filter? -> plain [no], filtering [yes]
filtering -> filtering [a click]
```
