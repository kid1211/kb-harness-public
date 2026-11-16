```graph
begin start
end rendered
external extension diffview
start: apply() gets the rendered HTML of a page.
start.run: emoji-bullets:emoji-bullets.js
item?: Does a list item start with an emoji?
bulleted: The item shows its emoji as its bullet, once, at its indent. A later emoji stays text.
bulleted.run: emoji-bullets:emoji-bullets.js
legend?: Is it a requirement item with a status emoji, or a Requirements heading?
legend: The item or heading gets the hover legend. On an item, its own status row stands out.
legend.run: emoji-bullets:emoji-bullets.js
rendered: The page is returned with its bullets and legends.
rendered.run: emoji-bullets:emoji-bullets.js
extension: The Markdown preview of vscode-draw-graph calls apply() once.
diffview: The Markdown Diff tab of vscode-draw-graph calls apply() once.
start -> item?
item? -> bulleted [yes], legend? [no]
bulleted -> legend?
legend? -> legend [yes], rendered [no]
legend -> rendered
```
