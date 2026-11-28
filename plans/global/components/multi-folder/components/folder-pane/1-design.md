# Domains pane: design

## State transitions

Model: [folder-pane.qnt](folder-pane.qnt).

```graph
import-graph: architecture.md
```

1. [closed](#closed): the row above the prompt shows the `domains` button. No pane of this mod is open.
2. [pressed](#pressed): The user pressed the button.
3. [loading](#loading): the pane is open, and the mod reads its data.
4. [shown](#shown): the pane shows the Active domain part, the "Pick one from this list" list and the hidden instructions part.
5. [picked](#picked): the user clicked a domain of the "Pick one from this list" list.

## State deep dive

### closed

The writing-mode line above the prompt holds a dim button, `⧉ domain`, left of `⚙ config`. Claude Code gives each mod its own line, so this mod draws no line: writing-mode draws the button, and a press runs `/domains toggle` of this mod. The glyph `⧉` is in the kitchen sink, kept by the user on 2026-11-20.

**Invariants:** none.

**Expected output:** no line of this mod. The button is in the writing-mode line.

### pressed

A press runs `/domains toggle`, the same toggle as `⚙ config`: on an open pane it closes it, on a closed pane it opens it. The mod owns its pane, so `$.ui.panes()` lists it. `/domains` alone only opens. Each open reads the data: the mod hooks `ui.open` of its own pane.

**Invariants:** none.

**Expected output:** the pane opens or closes.

### loading

The mod reads two session files in `~/.claude/multi-folder/<session id>/`: `dirs`, the added folders, and `instructions`, one `CLAUDE.md` per line with who loaded it. It runs `scripts/folder-context.py --json` of the checkout the session runs in, on the start folder and each added folder, and `scripts/project-map.py domains`. A missing file counts as empty.

**Invariants:** none.

**Expected output:** the data, in the mod's state.

### shown

The pane shows, from top to bottom:

1. **Active domain:** a heading in tan (`#D2B48C`), then the selected domain in light blue (`#A8D8EA`), then each added folder with its role, or `no row`, with no indent. The selected domain is each domain of the map whose folders are all added, less one whose folders all sit in another such domain. With none, the line says `none: pick one below`. The start folder is not listed: the session runs in it.
2. **Pick one from this list:** a heading in tan, then each domain of the map, numbered, each its own button, with no indent.
3. **Instructions:** a dim button, `show instructions (<n>)` or `hide instructions`. Hidden by default. When shown, one line per folder that holds a loaded `CLAUDE.md`, by its full path, with tags such as `at start`, `nested read`, `after compact` or `hook`, each once. Then the warning: `Claude Code 2.1.329 does not load the instructions of a subfolder in an added folder. The nested-instructions hook gives them. After a Claude Code update, check this again.`

Each added folder shows as its last three folder names, such as `test-folders/folder-a/web`. Each path is a `Link` to `file://<path>`. A `reload folders` button at the top reads the data again. A new `/add-dir` reads it again when the pane is open.

**Invariants:** `selectedLargest`, `instructionsListed`.

**Expected output:** the Active domain part, the "Pick one from this list" list and the instructions button.

### picked

A click writes a text to the chat by `$.ui.log`, one call per line, since a log line shows no line break: dim lines that the model never reads, so they cost no context. Then the pane closes. The text is one `/add-dir <folder>` line for each folder of the domain that is not added. If an added folder is not in the domain, the text also says that Claude Code cannot remove a folder from a running session, and gives `bash ~/second-brain/harness/scripts/project-start.sh <domain>` to start a new session with that domain alone. With every folder added and no other folder, the text says the domain is already selected.

**Invariants:** `pickAddsMissing`, `switchWhenOther`.

**Expected output:** the text of the pick, in the chat.

## Build checks

Unit tests: `.claude/skills/folder-pane/hooks/register.test.tsx`, run by `claude plugin test .claude/skills/folder-pane`, with stand-ins for the files and the scripts.

| Check | Holds |
|---|---|
| this mod draws no line; writing-mode draws `⧉ domain` left of `⚙ config` | `closed`, and the `folders button` test of writing-mode |
| a press opens the pane, and a press on the open pane closes it | `press`, `open`, `close`, `closeTest` |
| with web and api added, Active domain names mf-both and lists both folders with their roles | `draw`, `full`, `selectedOf`, `selectedLargest`, `drawTest` |
| the "Pick one from this list" part lists each domain, numbered; the headings are tan, the domain light blue, the items not indented | `draw`, F15 |
| each added folder shows its last three folder names | F16 |
| a click prints the `/add-dir` line of each folder not added | `pick`, `pickAddsMissing`, `pickTest` |
| a click with another folder added also prints the new-session command | `switchWhenOther`, `switchTest` |
| the instructions part is hidden, and its button shows it with the warning | `toggleInstructions`, `instructionsListed`, `instructionsTest` |

`claude plugin validate` and `tsc` check the mod. No check sees the pane in a live session: the user looks at it.

## Coverage

| Want | Held by |
|---|---|
| F1 | `press`, `open`, `close`, `closeTest` |
| F5 | `addDir` |
| F6 | `instructionsListed`, `drawTest` |
| F7 | the test of the instructions button: the warning shows with the part |
| F8 | not in the model, a view rule: the test checks each `Link` |
| F9 | `toggleInstructions`, `instructionsTest` |
| F11 | not in the model, a view rule: the `instructionFolders` test and `instructionsTest` |
| F12 | `selectedOf`, `selectedLargest`, `drawTest` |
| F13 | `pick`, `pickAddsMissing`, `pickTest` |
| F14 | `switchWhenOther`, `switchTest` |
| F15 | not in the model, a view rule: the `drawTest` test |
| F16 | not in the model, a view rule: the `lastParts` test |
| closed | `closeTest` |
| shown | `drawTest`, `instructionsTest` |
| picked | `pickTest`, `switchTest` |
| start and end | `initWith` starts closed, with the session files and the instructions hidden |
| negative control | `neverSwitch`: the checker finds a click that gives the new-session command |

## Risks

- The mod cannot ask Claude Code for the added folders. It reads the `dirs` file that the status line and the add-dir hook write. If the status line is off, a folder of `--add-dir` at launch is missing until the user adds one with `/add-dir`.
- The button lives in writing-mode. With writing-mode off, `/domains` still opens the pane.
- Claude Code has no command that removes an added folder: a switch needs a new session.
- A `file:` link opens what the terminal picks: a folder may open in Finder, not in the editor.
- The warning names version 2.1.329 by hand. After a check on a new version, edit the text.

## Appendix

- The spike of 2026-11-20 on the mod API of Claude Code 2.1.329: `$.ui.open`, `ui.render` on `Pane` and `AbovePrompt`, `$.fs.read`, `$.process.run`, `$.session.id`, and the hook events `DirectoryAdded` and `InstructionsLoaded`. The API has no call for the added folders.
- The mod to copy: `.claude/skills/writing-mode/hooks/register.tsx`.
