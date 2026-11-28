# Code reference: detailed requirements

## Requirements

- ✅ **R1. Copy a reference:** The user presses `Cmd+Shift+C`. The clipboard holds `@<full path>#L<start>-<end>` of the selected lines, or `@<full path>#L<n>` for one line. The user pastes it into the Claude Code session. No `/ide` connection is needed.
  - Serves: F1
- ✅ **R2. Four places:** The key works in a text editor, a text diff, the Markdown Diff and the Markdown preview. Each place has its own test.
  - Serves: F1
- ✅ **R8. No selection, no copy:** With nothing selected, in any of the four places, the key copies nothing and leaves the clipboard as it was. *(the user, 2026-10-21)*
  - Serves: F1
- ✅ **R4. Markdown Diff lines:** Each block of the Markdown Diff knows its lines in the new file. A removed block maps to the nearest line that is still in the file.
  - Serves: F1
- ✅ **R5. Markdown preview lines:** The preview's selection maps to source lines by the `data-line` of its blocks. The preview gives an extension no message channel, so the key starts a copy, and the page's script puts the line range in the clipboard. The extension reads it, then puts the user's clipboard back.
  - Serves: F1
- ✅ **R9. Git version in a text diff:** A side of a text diff that is a git version, not a file on disk, names that version: `@<full path> (version at <ref>, L<start>-<end>)`, with a commit as its first 7 characters. Claude reads those lines with `git show`. It is the old side of a working-tree diff, and both sides of a commit diff. *(the user, 2026-10-21)*
  - Serves: F1
- ✅ **R10. Status note:** A press shows its result in the same status-bar line as the hint of R11, never as a second line. On a copy: `TalkToClaude: copied req.md#L12-20. Switch to Claude and press Cmd+V.` The hint comes back after 6 seconds, or when the selection changes. *(the user, 2026-10-21)*
  - Serves: F2
- ✅ **R11. Live hint:** While one of the four places is active, one status-bar line says what to do next, the same in each place. With lines selected: `TalkToClaude: L12-20 selected. Press Cmd+Shift+C.` With nothing selected, or in the Markdown preview, which cannot report its selection: `TalkToClaude: select text, then press Cmd+Shift+C.` Elsewhere it shows nothing. *(the user, 2026-10-21)*
  - Serves: F2
- ✅ **R6. Path in a worktree:** The path is the file's full path, so it points at the right file from a session in a worktree or in the main checkout.
  - Serves: F1
- ✅ **R7. One key taken:** `Cmd+Shift+C` takes the key of VS Code's "Open New External Terminal". No other command loses its key.
  - Serves: F1
