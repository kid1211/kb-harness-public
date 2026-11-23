```graph
begin read
end plain
fail warned
external parse check
read: The library reads one node name of a graph block.
read.run: parse
fits?: Does the name have 6 words or fewer, counted by its `_` parts?
plain: The node draws with each `_` shown as a space, and no warning.
plain.run: parse
warned: The node draws, and the parse warns with its name and word count, so the graph check fails.
warned.run: parse
parse: The parse function of .claude/lib/draw-graph/draw-graph.js
check: The graph check, which fails a graph on each warning
read -> fits?
fits? -> plain [yes], warned [no]
warned -> check
```
