# vscode-draw-graph

A VS Code extension. It draws each ```` ```graph ```` block in VS Code's own Markdown
preview (⌘K V): group boxes, text on links, hover,
zoom, pan and the "transpose" button. It needs no server, and it works with the preview
security set to "Strict". The graph format is in the `draw-graph` skill.

Prototype, 2026-10-18. It has no plan yet.

## Markdown Diff (2026-10-19)

A diff of a `.md` file opens as a "Markdown Diff" tab: rendered Markdown, in the same tab
group. It uses `.claude/lib/markdown-diff/`:

- Added blocks are green, removed blocks red, and changed words marked in a changed block.
- The whole file shows. Unchanged blocks do not fold.
- A graph that did not change shows as the graph only. A changed graph shows its text,
  with the removed and added lines marked, then the new graph drawn. A removed graph folds.
- A strip on the right marks each change at its place in the page. Click a mark to scroll
  to it. A box on the strip shows the part in view.
- It updates on each edit of the file.
- It loads the same stylesheets as the Markdown preview, not copies: VS Code's own
  `markdown.css` and `highlight.css` from its `markdown-language-features` extension, with
  the preview's font settings, then `palette.css` and `preview.css`. The diff colours are
  `.claude/lib/markdown-diff/markdown-diff.css`.

Three ways in:

- **A click on a `.md` file in Source Control.** The extension closes the text diff tab VS
  Code opens and shows Markdown Diff instead. That includes a diff that replaces a preview
  tab, and a diff already open when the extension starts. A second diff of the same file
  replaces the first tab. If `"*.md"` is set to open in the preview, also set
  `"git:/**/*.md": "default"` in `workbench.editorAssociations`. Without it the diff opens
  as two previews, and VS Code's API gives that tab no input, so the extension cannot see it.
- **A click on a `.md` file in the Source Control Graph.** A changed file opens a diff, as
  above. A file the commit added has no old side, so VS Code opens it alone, as a `git:`
  text tab. If the commit's parent has no such file, the extension swaps that tab too, with
  every block marked as added. A deleted file stays a text tab.
- **A proposed edit from Claude Code (`/ide`).** Its diff tab stays open, because closing
  it rejects the edit. Markdown Diff opens beside it, without the focus, and closes when
  the diff tab closes. Accept or reject the edit in Claude's own diff tab, as before.

Only a diff of a `file:` or `git:` file is swapped. A diff from any other extension is left
alone.
- **"Markdown Diff: Open"**, the diff icon in a `.md` editor's title bar: the file against
  `HEAD`.
- The same command in the Source Control right-click menu.

## Front matter as a table (2026-10-19)

The YAML front matter at the top of a `.md` file (`--- ... ---`) shows as a `Key | Value`
table, in the preview and in Markdown Diff. A nested value, such as `hooks:`, shows one code
line per YAML line. In a diff, a changed key is a changed row. `frontmatter()` in
`.claude/lib/markdown-diff/markdown-diff.js` does it for both. It replaces the
`bierner.markdown-yaml-preamble` extension, which did not work in Markdown Diff.

## Set up on a new machine

1. Install Node and VS Code. Put `code` on the PATH ("Shell Command: Install 'code' command").
2. In the harness, run `npm install`. It gets the pinned marked and jsdiff.
3. Run `vscode-draw-graph/build.sh`. It needs the network once, for `vsce`.
4. In VS Code, run "Developer: Reload Window".
5. Open the harness folder. Its `.vscode/settings.json` holds the settings below.

| Setting | Value | Why |
|---|---|---|
| `workbench.editorAssociations` | `"*.md"`: the preview, `"git:/**/*.md"`: `"default"` | a `.md` file opens as the preview. A git diff stays a text diff, so the extension can swap it for Markdown Diff |
| `markdown.preview.fontSize` | `18` | The user's size |
| `markdown.preview.fontFamily` | SF Pro (`-apple-system`) | text font. Code uses the editor font |

These are workspace settings, so they apply only in the harness. To get them in another
folder, such as a KB, copy them into its `.vscode/settings.json` or into your user settings.

## Build and install

```sh
npm install                  # once per clone
vscode-draw-graph/build.sh
```

Then, in VS Code, run "Developer: Reload Window". The script builds `preview.bundle.js`,
packages `draw-graph-preview.vsix` with `vsce`, and installs it with `code
--install-extension`. Run it again after `.claude/lib/draw-graph/draw-graph.js` changes:
the extension holds a copy of it, made at build time.

## How it works

VS Code lets an extension add scripts and CSS to the Markdown preview, in `package.json`:

- `markdown.previewScripts` — `preview.bundle.js`.
- `markdown.previewStyles` — `palette.css`, copied from `.claude/lib/palette/` at build
  time, and `preview.css`. `preview.css` maps the `--dg-*` colours to the theme. In a
  dark theme, it also colours headings, bold, italic, links, inline code and `<mark>`
  from the palette.

`extension.js` is the `main`. Its `extendMarkdownIt` turns the front matter into a
table before markdown-it parses the text. The preview already writes a
```` ```graph ```` fence as `<pre><code class="language-graph">`. `preview.js` swaps each
one for a graph drawn by `DrawGraph.draw()`. VS Code replaces the page on each edit and
then fires `vscode.markdown.updateContent`, so the graphs are drawn again then.

**One bundle, not four scripts.** VS Code loads each preview script with `async`, so
their order is not fixed. The first build listed four scripts, and nothing drew.
`build.sh` joins Cytoscape, ELK, `draw-graph.js` and `preview.js`, in that order.

| File | What it is |
|---|---|
| `package.json` | the extension manifest |
| `preview.js` | finds each graph block and draws it |
| `preview.css` | the colours of the text and of a graph, and the box around a graph |
| `cytoscape.min.js` | Cytoscape.js 3.34.3 (MIT), from jsDelivr |
| `elk.bundled.js` | elkjs 0.12.0 (EPL-2.0), from jsDelivr |
| `build.sh` | builds the bundle, packages and installs |
| `extension.js` | opens Markdown Diff in place of a `.md` diff, and the command |
| `diff-view.js`, `diff-view.css` | the Markdown Diff page: graphs, the strip on the right |

`preview.bundle.js`, `palette.css`, `markdown-diff.js`, `markdown-diff.css`, `marked.min.js`, `diff.min.js` and
the `.vsix` are build output, and git ignores them. `build.sh` copies marked and jsdiff
from the harness's `node_modules` (`npm install` first), at the versions `package.json` pins.

## Tested

- In Chromium, with a page that copies the preview: the bundle loaded `async`, under the
  "Strict" policy copied from VS Code's `markdown-language-features`. The demo graph in
  `plans/plan-artifacts-demo/architecture.md` drew all 8 nodes. An edit cycle drew the
  new graph and freed the old one.
- In VS Code, by the user, 2026-10-18: the demo graph drew, interactive.
- There is no automated test.
- The rendered diff, 2026-10-19, by hand with throwaway scripts, not kept:
  - In VS Code 1.141.0 through `@vscode/test-electron`, with `*.md` set to the default
    editor, and to the preview plus `git:/**/*.md` set to the default: the git
    extension's `git.openChange` and the command each left one tab, the rendered diff.
    The page in the webview, under its CSP, loaded VS Code's `markdown.css` and reported
    the expected marks and words for `a.md` and `sub/a.md`. A diff that replaced a
    preview tab was swapped too.
  - In Chromium, the page with a plan file against an older version: the whole file, a
    mark per change, graphs drawn, no errors. A click on a mark scrolled to the change.
  - Not tested: what the page looks like inside VS Code itself.
