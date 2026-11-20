# Folder pane: design

## State transitions

Model: [folder-pane.qnt](folder-pane.qnt).

```graph
import-graph: architecture.md
```

1. [closed](#closed): the row above the prompt shows the `folders` button. No pane of this mod is open.
2. [pressed](#pressed): The user pressed the button.
3. [loading](#loading): the pane is open, and the mod reads its data.
4. [shown](#shown): the pane shows the coding folders, the KBs and the hidden instructions part.

## State deep dive

### closed

The writing-mode line above the prompt holds a dim `⧉ folders` button, left of `⚙ config`. Claude Code gives each mod its own line, so this mod draws no line: writing-mode draws the button, and a press runs `/folders toggle` of this mod. The glyph `⧉` is in the kitchen sink, kept by the user on 2026-11-20.

**Invariants:** none.

**Expected output:** no line of this mod. The button is in the writing-mode line.

### pressed

A press runs `/folders toggle`, the same toggle as `⚙ config`: on an open pane it closes it, on a closed pane it opens it. The mod owns its pane, so `$.ui.panes()` lists it. `/folders` alone only opens. Each open reads the data: the mod hooks `ui.open` of its own pane.

**Invariants:** none.

**Expected output:** the pane opens or closes.

### loading

The mod reads two session files in `~/.claude/multi-folder/<session id>/`: `dirs`, the added folders, and `instructions`, one `CLAUDE.md` per line with who loaded it. It runs `scripts/folder-context.py --json` of the checkout the session runs in, on the start folder and each added folder. A missing file counts as empty.

**Invariants:** none.

**Expected output:** the data, in the mod's state.

### shown

The pane shows, from top to bottom:

1. **Coding folders:** each added folder that is not a KB, with its project, or `not on the map`. The start folder is not listed: the session runs in it.
2. **KBs:** each added KB folder, and each KB folder that the map gives a project of the session, with the project. A KB of the map that is not added is marked `not added`. The supporting docs of a project are its KBs, so there is no other part.
3. **Instructions:** a dim button, `show instructions (<n>)` or `hide instructions`. Hidden by default. When shown, each `CLAUDE.md` of the `instructions` file, with who loaded it, then the warning: `Claude Code 2.1.329 does not load the instructions of a subfolder in an added folder. The nested-instructions hook gives them. After a Claude Code update, check this again.`

Each coding folder and KB shows relative to the start folder, such as `../personal`. The instructions part shows one line per folder, by its full path, with tags such as `at start`, `nested read`, `after compact` or `hook`, each once. The warning is the last line of the pane. Each folder and file path is a `Link` to `file://<path>`, with the full path. A click opens it, in the app the terminal picks for a `file:` link.

A `Refresh` button reads the data again. A new `/add-dir` reads it again when the pane is open.

**Invariants:** `noStart`, `eachAddedOnce`, `kbsFromMap`, `instructionsListed`.

**Expected output:** the coding folders, the KBs and the instructions button.

## Build checks

Unit tests: `.claude/skills/folder-pane/hooks/register.test.tsx`, run by `claude plugin test .claude/skills/folder-pane`, with stand-ins for the files and for `folder-context.py`.

| Check | Holds |
|---|---|
| this mod draws no line; writing-mode draws `⧉ folders` left of `⚙ config` | `closed`, and the `folders button` test of writing-mode |
| a press opens the pane, and a press on the open pane closes it | `press`, `open`, `close`, `closeTest` |
| the coding part lists the code folders and a folder on no row, not the start folder | `draw`, `codingOf`, `noStart`, `eachAddedOnce`, `drawTest` |
| the KBs part lists the added KB and the KB of the map, marked `not added` | `kbsOf`, `kbsFromMap`, `drawTest` |
| each path is a `Link` to `file://<path>` | no model rule: the test holds it |
| each path shows relative to the start folder, or from `~` past two folders up | no model rule: the `shortPath` test holds it |
| the instructions part is hidden, and its button shows it with the warning | `toggleInstructions`, `instructionsListed`, `instructionsTest` |
| an add while the pane is open draws the new folder | `addDir`, `addTest` |

`claude plugin validate` and `tsc` check the mod. No check sees the pane in a live session: The user looks at it.

## Coverage

| Want | Held by |
|---|---|
| F1 | `press`, `open`, `close`, `closeTest` |
| F2 | `draw`, `codingOf`, `noStart`, `eachAddedOnce`, `drawTest` |
| F3 | `kbsFromMap`, `eachAddedOnce`, `drawTest` |
| F4 | `kbsFromMap`: one KBs part, no docs part |
| F5 | `addDir`, `addTest` |
| F6 | `instructionsListed`, `drawTest` |
| F7 | the test of the instructions button: the warning shows with the part |
| F8 | not in the model, a view rule: the test checks each `Link` |
| F9 | `toggleInstructions`, `instructionsTest` |
| F10 | not in the model, a view rule: the `shortPath` test |
| F11 | not in the model, a view rule: the `instructionFolders` test and `instructionsTest` |
| closed | `closeTest` |
| shown | `drawTest`, `instructionsTest`, `addTest` |
| start and end | `initWith` starts closed, with the session files and the instructions hidden |
| negative control | `neverShared`: the checker finds two folders in the coding part |

## Risks

- The mod cannot ask Claude Code for the added folders. It reads the `dirs` file that the status line and the add-dir hook write. If the status line is off, a folder of `--add-dir` at launch is missing until the user adds one with `/add-dir`.
- The button lives in writing-mode. With writing-mode off, `/folders` still opens the pane.
- A `file:` link opens what the terminal picks: a folder may open in Finder, not in the editor.
- The warning names version 2.1.329 by hand. After a check on a new version, edit the text.

## Appendix

- The spike of 2026-11-20 on the mod API of Claude Code 2.1.329: `$.ui.open`, `ui.render` on `Pane` and `AbovePrompt`, `$.fs.read`, `$.process.run`, `$.session.id`, and the hook events `DirectoryAdded` and `InstructionsLoaded`. The API has no call for the added folders.
- The mod to copy: `.claude/skills/writing-mode/hooks/register.tsx`.
