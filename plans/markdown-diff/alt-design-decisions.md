# Markdown diff: designs not chosen

- **A diff of the HTML of the full page, word by word.** Not chosen: a tag can be cut. A moved part looks like a rewrite.
- **A diff of the Markdown text, rendered after.** Not chosen: a mark inside a table or a code fence breaks the Markdown. Each part is rendered first, then marked.
- **Merge a changed code part word by word.** Not chosen: a graph would show half-old and half-new nodes. The old one shows as removed and the new one as added.
- **A model with a list of parts.** Not chosen: `render()` decides on each part alone, so one part shows every move.
