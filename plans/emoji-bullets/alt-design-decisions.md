# Emoji bullets: designs not chosen

- **A rule inside the markdown-it renderer.** Not chosen: the Markdown Diff tab renders with `marked`, not markdown-it. One function on the finished HTML (`apply()`) serves both, and removing it is one call per place (R4).
- **CSS only, with `li::marker`.** Not chosen: CSS cannot read the first character of an item, so it cannot pick the emoji.
- **A legend drawn by a CSS `::after` on hover.** Not chosen: one row of it must stand out (R5), and a pseudo-element cannot mark one row. The legend is a real `<span>`.
- **A model with one state per list item.** Not chosen: `apply()` treats each item alone, so one item shows every move.
