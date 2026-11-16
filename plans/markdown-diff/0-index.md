# Markdown diff

## Goal

A shared library that shows two versions of a Markdown file as rendered Markdown, with the added, removed and changed parts marked. The Markdown Diff tab of vscode-draw-graph uses it. Draft.

Builds: `.claude/lib/markdown-diff/`, used by the Markdown Diff tab of `vscode-draw-graph/`
Uses: marked, jsdiff, draw-graph

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** I see what changed in a Markdown file as rendered Markdown, with the changes marked.
  Decision: pending
  Built: 1 of 1
  What Claude thinks the user means: Old and new text in, one rendered page out: added green, removed red, changed words marked.

## Open questions

- ⚠️ designed check 2026-11-02 (Frieren; all minor):
  - minor: `addedWhole`, `removedWhole`, `sameNoMark` check nothing at Rendered (`markdown-diff.qnt:71-75`).
  - minor: R1 does not name the front matter table or fold, which the graph and code have.
  - minor: `drawgraph` has no link in the graph. minor: `delins` is a fifth outcome the graph does not show. minor: `1-design.md:18` "any combination" is wrong. minor: `alt-design-decisions.md` says "part" for "block".

## Research questions

### User

TBD

### Claude

TBD
