# Markdown diff: design

## State transitions

Model: [markdown-diff.qnt](markdown-diff.qnt), module `markdownDiff`.

```graph
import-graph: architecture.md
```

1. **Start:** `render(oldText, newText)` gets the two texts (`initWith`). [Deep dive](#start)
2. **Frontmatter:** YAML front matter becomes a key and value table (`toFrontmatter`). [Deep dive](#frontmatter)
3. **Split:** each text becomes its top-level blocks (`toSplit`). [Deep dive](#split)
4. **Compare:** jsdiff pairs the old blocks with the new ones (`toCompare`). [Deep dive](#compare)
5. **Marked:** each block gets its mark (`markBlock`). [Deep dive](#marked)
6. **Rendered:** the page is returned (`finish`). [Deep dive](#rendered)

The model has one block. `render()` decides on each block alone, once jsdiff has paired them. The flags `inOld`, `inNew`, `same`, `alike` and `isCode` start in any combination, with the block on at least one side.

## State deep dive

### Start

`MarkdownDiff.render(oldText, newText, deps)` uses the globals `marked` and `Diff`, or `deps`. A missing side is an empty text: a new file is all added, a deleted file all removed.

- **Invariants:** none yet.
- **Expected output:** none yet.

### Frontmatter

- A `---` block at the top of a text becomes a `Key | Value` table. A nested value shows one code line per YAML line. The table diffs row by row.
- **Invariants:** none yet.
- **Expected output:** the text with a table in place of the front matter.

### Split

- `marked.lexer` gives the top-level blocks. The blocks of space are dropped.
- **Invariants:** none yet.
- **Expected output:** the list of blocks of each text.

### Compare

- `Diff.diffArrays` pairs the blocks by their raw text. A removed run followed by an added run pairs in place, block by block.
- **Invariants:** none yet.
- **Expected output:** parts that are kept, removed or added.

### Marked

- A kept block has no mark. A block only in the new text is `<div class="md-ins">`. A block only in the old text is `<div class="md-del">`.
- Two paired blocks of one type that share more than 40% of their text are `<div class="md-chg">`, with `<ins>` and `<del>` on the words inside. Else the old block is removed and the new one added, whole.
- A code block never merges, a graph block too.
- **Invariants:** `addedWhole`, `removedWhole`, `sameNoMark`, `codeNeverMerges`, `chgOnlyAlike`.
- **Expected output:** one HTML string for the page.

### Rendered

- The caller sets the HTML, may call `MarkdownDiff.fold(el)`, and draws each graph block with draw-graph.
- **Invariants:** `addedWhole`, `removedWhole`, `sameNoMark`.
- **Expected output:** the page. The action `done` keeps a finished run where it ended.

## Build checks

Unit tests: `node --test .claude/lib/markdown-diff/tests/markdown-diff.test.js`. One test per invariant and per expected output.

| Test | Holds |
|---|---|
| an unchanged file renders with no marks | `sameNoMark`, `sameTest`, R1 |
| an added and a removed block are wrapped whole | `addedWhole`, `removedWhole`, `addedTest`, `removedTest`, R1 |
| a changed paragraph marks only the changed words, inside rendered Markdown | `chgOnlyAlike`, `changedTest`, R1 |
| a changed code block (a graph too) shows old as removed and new as added | `codeNeverMerges`, `codeTest`, R1 |
| a rewritten paragraph is a removal and an addition, not a word soup | `chgOnlyAlike`, R1 |
| a new file is all added, a deleted file all removed | `addedWhole`, `removedWhole`, R1 |
| front matter renders as a key and value table, a nested value as code lines | the Frontmatter state, R1 |
| a finished page is returned as one string (`renderedTest`, `done`) | the Rendered state, R1 |

The negative control `neverChanged` must fail. The state check is `C flow`.

No check can see:

- That added is green and removed is red. The colours are in `markdown-diff.css`, and the user looks at the preview.
- That draw-graph draws each graph block. The caller does it, in the extension, so this library has no test for it.

## Coverage

| Requirement | Held by |
|---|---|
| R1 | `markBlock`, `addedWhole`, `removedWhole`, `sameNoMark`, `codeNeverMerges`, `chgOnlyAlike`, and the unit tests above. The colours and the graph blocks: see "No check can see". |
| start | `initWith`, `changedTest` |
| frontmatter | `toFrontmatter`, the front matter test |
| split | `toSplit`, `changedTest` |
| compare | `toCompare`, `changedTest` |
| marked | `markBlock`, `sameTest` |
| rendered | `finish`, `done`, `renderedTest` |

## Risks

- **A run that inserts one block and edits the next may pair the wrong two.** The word diff then shows more red and green than it should. Nothing is lost. The 40% rule limits it.
- **Front matter is read by line, not by a YAML parser.** A flow list or a multi-line quoted string shows raw. The code marks this with a `ponytail:` comment.
- **The model has one block,** so it cannot show a wrong pairing of two blocks. The tests with real text hold that.

## Appendix

- Code: `.claude/lib/markdown-diff/markdown-diff.js` and `markdown-diff.css`. Caller: the Markdown Diff tab of `vscode-draw-graph/`.
- The old research on libraries (marked, jsdiff) is in the git history of `plans/plan-artifacts-viewer/`.
