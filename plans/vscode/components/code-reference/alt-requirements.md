# Code reference: dropped and changed requirements

## R3. No selection

**Requirement:** With no selection in a text editor or a text diff, the reference is the line of the cursor.

**Why it is not chosen:** The user wants the same rule in all four places: with nothing selected, nothing is copied. R8 replaces it. Dropped 2026-10-21.

## R10. Status note, first wording

**Requirement:** On a copy: `TalkToClaude: copied req.md#L12-20. Paste with Cmd+V.` With nothing selected: `TalkToClaude: nothing selected. Select lines, press Cmd+Shift+C, then Cmd+V.`

**Why it is not chosen:** It did not say where to paste. The user wants it to say: switch to Claude, then press Cmd+V. R10 has the new wording. Changed 2026-10-21.

## R9. Old side of a text diff, first form

**Requirement:** The old side is a git version, not a file on disk. A selection there copies `@<full path> (old version at <ref>, L<start>-<end>)`, so Claude knows to read the lines with `git show`. *(the user, 2026-10-21)*

**Why it is not chosen:** In a commit diff the new side is a git version too, and "old version" named it wrongly. The user's test showed `old version at 5f56641…` for a line the commit added. R9 now says "version at", with a short commit ID. Changed 2026-10-21.

## R10 and R11, first form

**Requirement:** Each press shows one short line in the status bar. On a copy: `TalkToClaude: copied req.md#L12-20. Switch to Claude and press Cmd+V.` With nothing selected: `TalkToClaude: nothing selected. Select lines, press Cmd+Shift+C, then Cmd+V in Claude.` *(the user, 2026-10-21)*

While one of the four places is active, the status bar shows what to do next, before any press. With lines selected: `TalkToClaude: L12-20 selected. Press Cmd+Shift+C, then Cmd+V in Claude.` With nothing selected: `TalkToClaude: select text to start.` The Markdown preview gives no channel for its selection, so there it shows `TalkToClaude: select text, then press Cmd+Shift+C.` Elsewhere it shows nothing. *(the user, 2026-10-21)*

**Why it is not chosen:** The note of a press and the hint showed as two lines side by side. The hint named Cmd+V before any copy, and had three wordings. The user wants one line, one wording for every place, and Cmd+V only after a copy. Changed 2026-10-21.
