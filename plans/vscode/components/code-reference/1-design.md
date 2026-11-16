# Code reference: design

## State transitions

Model: [code-reference.qnt](code-reference.qnt), module `codeReference`.

```graph
import-graph: architecture.md
```

1. **Idle:** no place is active. The status bar shows no hint (`initWith`). [Deep dive](#idle)
2. **Hinted:** one of the four places is active, and the hint line shows (`activate`). [Deep dive](#hinted)
3. **Pressed:** The user pressed `Cmd+Shift+C` (`press`). [Deep dive](#pressed)
4. **Waiting:** the press was in the Markdown preview, and the page has put its mark in the clipboard (`askPreview`). [Deep dive](#waiting)
5. **Copied:** the place gave lines, and the clipboard holds the reference (`resolve`, `readMark`). [Deep dive](#copied)
6. **Kept:** the place gave no lines, and the clipboard is as it was (`resolve`, `readMark`). [Deep dive](#kept)

The model has one press. `initWith` picks the place and whether it has selected lines. The decisions `preview?` and `lines?` sit inside `askPreview`, `resolve` and `readMark`. `done` keeps a finished press where it ended.

## State deep dive

### Idle

- The tab is none of the four places, or no tab is active. The command returns at once and the status bar shows nothing (R11).
- **Invariants:** none.
- **Expected output:** none yet.

### Hinted

- The hint is one line, the same in each place: `TalkToClaude: L12-20 selected. Press Cmd+Shift+C.`, or `TalkToClaude: select text, then press Cmd+Shift+C.` for no lines and for the Markdown preview (R11).
- **Invariants:** none.
- **Expected output:** none yet.

### Pressed

- A text editor gives the lines of its selections, and a selection that ends at the start of a line does not take that line. A text diff gives the same, with the git version named for a side that is not a file (R9). The Markdown Diff gives the `data-src-lines` of the blocks at the two ends of the selection (R4).
- **Invariants:** `markNotLeft`.
- **Expected output:** none yet.

### Waiting

- The key arms a copy in the preview page. The page script puts `TalkToClaude-lines:<source>#<start>-<end>` in the clipboard, from the `data-line` of the blocks (R5). The extension reads it and puts the user's clipboard text back.
- **Invariants:** `markNotLeft`, `previewRestores`.
- **Expected output:** none yet.

### Copied

- The clipboard holds `@<full path>#L<start>-<end>`, or `@<full path>#L<n>` for one line (R1, R6). A git version gives `@<full path> (version at <ref>, L<start>-<end>)` (R9). The status bar shows `TalkToClaude: copied req.md#L12-20. Switch to Claude and press Cmd+V.` and the hint comes back after 6 seconds (R10).
- **Invariants:** `copyIsRef`, `previewRestores`.
- **Expected output:** the clipboard text above.

### Kept

- Nothing is selected. The clipboard is as it was, and the status bar shows the hint of R11 (R8).
- **Invariants:** `noSelectionKept`, `previewRestores`.
- **Expected output:** the clipboard unchanged.

## Build checks

Unit tests, run with `node --test .claude/lib/code-reference/tests/code-reference.test.js`. The functions are pure and take plain objects, so the tests need no VS Code.

| Test | Holds |
|---|---|
| text editor: the selected lines, 1-based, as `@path#L` | R1, R2, R6, `copyIsRef` |
| text editor: a selection that ends at the start of a line does not take that line | R1 |
| nothing selected: null, and the note says how | R8, `noSelectionKept` |
| text diff: a git version names its ref, a file names none | R9 |
| the live hint: lines selected, or nothing selected, one wording for every place | R11 |
| the note names the file and the lines | R10 |
| Markdown preview: from the start block to the line before the next block, nested blocks too | R5 |
| Markdown preview: the page's answer in the clipboard | R5, `markNotLeft` |
| blank lines at the end of a range are dropped | R1 |

The negative control `neverCopied` must fail. The model checks are `npx quint test` and `npx quint run --invariant`.

No check can see:

- the key press in a real VS Code, in each of the four places. The user presses it.
- that the extension puts the user's clipboard back after a preview press (`previewRestores`). It needs VS Code's clipboard.
- the Markdown Diff lines of R4 (`data-src-lines`). Its tests are in `markdown-diff`.
- R7, that `Cmd+Shift+C` takes the key of "Open New External Terminal". It is a line of `package.json`.

## Coverage

| Requirement | Held by |
|---|---|
| R1 | `copyTest`, `copyIsRef`, and the text editor tests |
| R2 | `initWith` takes each of the four places, `copyTest`, and one unit test per place |
| R4 | Not in the model: the `markdown-diff` tests hold `data-src-lines` |
| R5 | `readMark`, `markNotLeft`, `previewRestores`, `previewTest`, and the preview tests |
| R6 | The editor test: the reference holds the full path |
| R7 | Not in the model: one line of `package.json`, which the user sees in the keybindings |
| R8 | `noSelectionKept`, `keptTest`, and the nothing-selected test |
| R9 | The git version test. Not in the model, since the text of a reference is not modelled |
| R10 | The note test. The 6 second return of the hint is not in the model |
| R11 | The hint test. The hint is not in the model |
| copied | `copyTest`, `previewTest` |
| kept | `keptTest` |

## Risks

- **The preview gives the extension no channel.** The mark in the clipboard is the only way out. If the page script does not answer within the wait, the press does nothing. `previewRestores` keeps the user's text.
- **A press in an image or other clipboard.** Only text is put back, so an image in the clipboard is lost after a preview press. This is a known limit in the code.
- **The place cannot be told.** A tab that is none of the four ends the command at once.

## Appendix

- Library: `.claude/lib/code-reference/code-reference.js`. The command: `vscode-draw-graph/extension.js`, `codeReference.copy`.
