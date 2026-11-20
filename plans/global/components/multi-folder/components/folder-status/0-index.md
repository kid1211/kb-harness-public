# Folder status

## Goal

The status line names each folder the session works on: the start folder and each added folder, with the project of each from the map. The user sees at a glance what the session touches.

Route: poc

Builds: `scripts/statusline-folders.sh` (one status line part from the status line input), `tests/global/folder-status/`, and its line in `mac-setup/claude-code-setup.md`
Uses: the status line input `workspace.added_dirs`, `~/.claude/statusline.sh`, `scripts/project-map.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, from the parent level `plans/global/components/multi-folder/`.

- **F1.** The status line shows each added folder by a short name, next to the start folder and branch it shows now. *(the user, 2026-11-19)*
- **F2.** A folder on the map shows its project name. Two folders of one project show the project once. *(the user, 2026-11-19)*
- **F3.** With no added folder, the status line looks as it does now. *(the user, 2026-11-19)*
- **F4.** The script writes the added folders of the session to a session file, so the add-dir context, the nested-instructions hook and the folder pane know them, also the folders of `--add-dir` at launch. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
