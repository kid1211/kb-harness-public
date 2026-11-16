```graph
begin start
end rendered
external drawgraph
start: render() gets the old and the new text of a Markdown file.
start.run: markdown-diff:markdown-diff.js
frontmatter: YAML front matter at the top of each text becomes a key and value table, so it diffs row by row.
frontmatter.run: markdown-diff:markdown-diff.js
split: Each text becomes its top-level blocks: a paragraph, a heading, a list, a code block.
split.run: markdown-diff:markdown-diff.js
compare: jsdiff pairs the old blocks with the new ones. A removed run then an added run pairs in place.
compare.run: markdown-diff:markdown-diff.js
marked: Each block is kept, added, removed or changed. A changed block marks its words, inside the block.
marked.run: markdown-diff:markdown-diff.js
rendered: The page is one HTML string. The caller can fold the unchanged blocks.
rendered.run: markdown-diff:markdown-diff.js
drawgraph: The caller draws each graph block with draw-graph, after render.
start -> frontmatter
frontmatter -> split
split -> compare
compare -> marked
marked -> rendered
```
