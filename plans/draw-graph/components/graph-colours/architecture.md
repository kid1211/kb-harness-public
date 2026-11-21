```graph
begin read
end plain applied
fail error
external palette check parse
read: The library reads one line of a graph block.
read.run: parse
color?: Is it a colour line, such as `color a text=tan fill=midnight`?
plain: The line is not a colour line. Each node and link keeps the colour of its kind.
plain.run: parse
known?: Is each colour a name in the palette, other than firebrick?
fits?: Does each colour fit its part? A dark fill colour goes on a fill only, never on text or a line.
applied: The node or link takes the colours. They win over the colour of its kind.
applied.run: parse
error: The graph shows an error that names the line and the colour, and the graph check fails.
error.run: parse
palette: The palette of .claude/lib/palette/, with the colour names and values
parse: The parse function of .claude/lib/draw-graph/draw-graph.js
check: The graph check, which fails a graph that shows an error
read -> color?
color? -> plain [no], known? [yes]
known? -> fits? [yes], error [no]
fits? -> applied [yes], error [no]
known? -> palette
error -> check
```
