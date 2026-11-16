# Code reference

## Goal

Cmd+Shift+C copies a reference to the selected lines, @/full/path/file#L12-20, to the clipboard. The user pastes it into the Claude Code session in the terminal, so no /ide connection is needed. It works in a text editor, a text diff, the Markdown Diff and the Markdown preview. Draft.

Builds: `.claude/lib/code-reference/`, and the source lines of each block in `.claude/lib/markdown-diff/`
Uses: VS Code's extension API, the `data-line` of each block in VS Code's Markdown preview

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** I copy a line reference with one key and paste it into Claude.
  Decision: pending
  Built: 7 of 8
  What Claude thinks the user means: I want a full-path reference to my selected lines from any of four places.
- **F2.** The status bar tells me what the key does.
  Decision: pending
  Built: 0 of 2
  What Claude thinks the user means: I want a hint and a result note in one line.

## Open questions

- ⚠️ built check 2026-11-02 (Frieren): [major] a late preview answer can leave the mark in the clipboard (extension waits 1 s, page stays armed 2 s, `extension.js:240`, `code-reference.js:95`). The fix is in `vscode-draw-graph/extension.js`, which plan-preview also names. minor: `diffLines()` has no test, R6 full path has no test, R9 cuts only a bare 40-hex ref, `selected()` and the hint disagree on what a place is, an image on the clipboard is lost, Built counts stale.
- ⚠️ designed check 2026-11-02 (Frieren):
  - [major] `waiting` has one exit (`architecture.md:23`, `code-reference.qnt:52`), but `1-design.md:102` describes a timeout where the press does nothing, and a late page answer could leave the mark in the clipboard. `markNotLeft` cannot catch it. A timeout edge and action are needed.
  - [major] With nothing selected in the preview, the page may put no range. Unsure if the press goes to `kept` or the timeout path (`code-reference.qnt:39`, R5).
  - minor: `previewRestores` is empty on `copied`. minor: no Markdown Diff row in Build checks (`1-design.md:62-72`). minor: status text after `kept` differs across files. minor: no `hinted -> idle` edge or selection change. minor: R10 should say only the 6-second timer brings the hint back in the preview. minor: `idle` holds a place in the model, none in the graph.
- ⚠️ The calls in `vscode-draw-graph/extension.js` and `package.json` are not on the `Builds:` line. `plan-preview` names the same two files, and the split check allows one level per path. The user or `p-req` can decide which level owns them. (Claude, 2026-11-02, recommended: keep as is)

## Research questions

### User

TBD

### Claude

TBD
