# palette

The dark-theme colours of every HTML page Claude makes: Artifacts, and
VS Code's Markdown preview (`vscode-draw-graph`). The user picked them on 2026-10-10 from two
palettes, "Deep Indigo Ocean" and "Earth & Bamboo". Keep the page's dark neutral
background and use these for the text that must stand out.

`palette.css` defines each colour as a `--pal-*` custom property. A page loads it, then
maps the `--pal-*` names to its own roles. If a page cannot load a file, such as an
Artifact, copy the values.

| Use | Colour | Property |
|---|---|---|
| Headings | `#D2B48C` tan | `--pal-tan` |
| Bold text | `#FAF0E6` linen | `--pal-linen` |
| Italic text, like the citations | `#D2B48C` tan | `--pal-tan` |
| Links, active tags, ticked boxes | `#A8D8EA` light blue | `--pal-light-blue` |
| Inline code (text, fill) | `#A8D8EA` light blue, `#001F3F` navy | `--pal-light-blue`, `--pal-navy` |
| Highlight, `<mark>` (fill, text) | `#D2B48C` tan, `#001F3F` navy | `--pal-tan`, `--pal-navy` |
| Icon buttons (background, glyph) | `#4A6A88` slate blue, `#FFFFFF` | `--pal-slate-blue`, `--pal-white` |
| Secondary tags (citations), word being read | `#D2B48C` tan, glyph on it `#001F3F` navy | `--pal-tan`, `--pal-navy` |
| Block being read, rules, quote bars | `#4A6A88` slate blue | `--pal-slate-blue` |
| Errors, missing tags (background, text) | `#B22222` firebrick, `#FAF0E6` | `--pal-firebrick`, `--pal-linen` |
| A graph's good end (fill) | `#4F7942` fern, added 2026-10-23 | `--pal-fern` |
| Spare: dark fills | `#001F3F` navy, `#191970` midnight blue, `#363636` charcoal, `#6B7158` olive | `--pal-navy`, `--pal-midnight`, `--pal-charcoal`, `--pal-olive` |

Firebrick and the dark fills are too dark for text on a dark background. Use them as fills
only.

## Who loads it

- `vscode-draw-graph/build.sh` copies it into the extension. `preview.css` maps it in the
  Markdown preview when the VS Code theme is dark.

## Kitchen sink

`kitchen-sink.md` shows every colour, graph part, icon and emoji on one page, in the theme that is open. The user reviews it there, and what the user keeps moves into this table and the skills.
