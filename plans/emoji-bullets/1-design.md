# Emoji bullets: design

## State transitions

Model: [emoji-bullets.qnt](emoji-bullets.qnt), module `emojiBullets`.

```graph
import-graph: architecture.md
```

1. **Start:** `apply()` gets the rendered HTML of a page (`initWith`). [Deep dive](#start)
2. **Bulleted:** an item that starts with an emoji shows it as its bullet (`markBullet`). [Deep dive](#bulleted)
3. **Legend:** a requirement item or a Requirements heading gets the hover legend (`addLegend`). [Deep dive](#legend)
4. **Rendered:** the page is returned (`finish`). [Deep dive](#rendered)

The model has one item. `apply()` treats each item alone, so one item shows every move. The input flags `leadEmoji`, `isReq` and `isHeading` start in any combination.

## State deep dive

### Start

`EmojiBullets.apply(html)` runs on a page after the Markdown is rendered. The VS Code preview calls it from `extension.js`. The Markdown Diff tab calls it from `diff-view.js`. Each place has one call. An item with no emoji goes straight to Rendered (`skipAll`), and a heading goes straight to Legend (`headingLegend`).

- **Invariants:** `bulletIffEmoji`.
- **Expected output:** none yet.

### Bulleted

- A `<li>` whose text starts with an emoji gets `style="list-style-type: '<emoji> '"`. The emoji is the bullet once, at the indent of the item. An emoji later in the text stays text.
- An item that already has a `style` is left as it is, so the attributes of the preview stay.
- **Invariants:** `bulletIffEmoji`.
- **Expected output:** the `<li>` with the style. A plain item is unchanged.

### Legend

- An item `- <status emoji> **R<n>…` gets `data-legend` and a `.eb-legend` span with four rows, one per status of `p-z-helper-file-structure`. The row of the item's own status has the class `eb-on`, and `emoji-bullets.css` paints it white with dark text.
- A `Requirements` heading gets the same legend and no `eb-on` row.
- **Invariants:** `legendOnlyWhereAsked`, `rowOnlyOnItem`, `itemRowMarked`.
- **Expected output:** the item or heading with the legend span.

### Rendered

- **Invariants:** `legendOnlyWhereAsked`, `itemRowMarked`.
- **Expected output:** the HTML string, with bullets and legends. An emoji item that is no requirement item comes here from Bulleted (`finishBulleted`). The action `done` keeps a finished run where it ended.

## Build checks

Unit tests: `node --test .claude/lib/emoji-bullets/tests/emoji-bullets.test.js`. One test per invariant and per expected output.

| Test | Holds |
|---|---|
| an emoji at the start of an item is the bullet in place of the dot, once, at every depth | `bulletIffEmoji`, R1 |
| a requirement item and the Requirements heading get the legend, other items do not | `legendOnlyWhereAsked`, R2 |
| on an item the row of its own status is marked, on the heading no row | `rowOnlyOnItem`, `itemRowMarked`, R5 |
| the attributes of the VS Code preview are kept | R3 |
| an item with an emoji and no requirement mark ends with its bullet and no legend (`finishBulleted`, `bulletOnlyTest`) | R1 |
| a page given twice to `apply()` is not changed the second time (`done`: a finished run stays) | R1 |

The negative control `noBulletEver` must fail. `quint test` runs `itemTest`, `headingTest`, `plainTest` and `renderedTest`.

No check can see:

- R4: that each place that uses it has one `apply()` call, and that removing it takes only the folder, those calls, the stylesheet and one line of `build.sh`. A `grep emoji-bullets vscode-draw-graph/` shows it.
- How the emoji looks in VS Code. The user looks at the preview.

## Coverage

| Requirement | Held by |
|---|---|
| R1 | `markBullet`, `bulletIffEmoji`, `itemTest`, `plainTest`, the bullet test |
| R2 | `addLegend`, `legendOnlyWhereAsked`, `headingTest`, the legend test |
| R3 | The preview-attributes test. The two places that call `apply()` are external nodes of the graph. |
| R4 | Not in the model: it is a layout rule. See "No check can see". |
| R5 | `rowOnlyOnItem`, `itemRowMarked`, `itemTest`, `headingTest`, the row test |
| start, bulleted, legend | `itemTest`, `plainTest`, `headingTest`, `bulletOnlyTest` |
| rendered | `renderedTest`, `done` |

## Risks

- **A list item that starts with an emoji that is not a status gets a bullet and no legend.** That is wanted: the legend is for the four statuses only.
- **The regular expression reads HTML.** A `<li>` with a nested tag before the text may not match. The tests cover the marked and `<p>` forms that `marked` and markdown-it give.
- **The status list is copied from `p-z-helper-file-structure` R107.** If the statuses change, `STATUS` in `emoji-bullets.js` changes too. No check links them.

## Appendix

- Code: `.claude/lib/emoji-bullets/emoji-bullets.js` and `emoji-bullets.css`. Callers: `vscode-draw-graph/extension.js`, `vscode-draw-graph/diff-view.js`, `vscode-draw-graph/build.sh`.
