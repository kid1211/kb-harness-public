```graph
begin read
end one_line wrapped
external layout check
read: The library reads the text of one link of a graph block.
read.run: layout
fits?: Is the text as wide as the max width or less?
one_line: The text sits on one line, in a gap it cuts in the link.
one_line.run: layout
wrapped: The text wraps word by word, and the gap in the link fits all its lines.
wrapped.run: layout
layout: The layout function of .claude/lib/draw-graph/draw-graph.js, with ELK's inline link text
check: The graph check, which fails a graph on overlaps and crossings
read -> fits?
fits? -> one_line [yes], wrapped [no]
one_line -> check
wrapped -> check
```
