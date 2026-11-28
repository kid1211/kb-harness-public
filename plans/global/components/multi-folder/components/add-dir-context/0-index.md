# Add-dir context

## Goal

When the user adds a folder with /add-dir, a hook tells Claude the project of the folder, its role, and the KB folders that go with it, from the project map. The user does the /add-dir.

Route: poc

Builds: `.claude/hooks/add-dir-context.sh`, `scripts/folder-context.py`, `.claude/settings.json` (its DirectoryAdded and UserPromptSubmit lines), and `tests/global/add-dir-context/`
Uses: the `DirectoryAdded` hook event of Claude Code, `scripts/project-map.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-20.

- **F1.** When the user adds a folder with `/add-dir`, Claude gets the context of the folder from the project map: its project, its role, and the supporting docs of the project, the KB folders, each with its role. *(the user, 2026-11-20)*
- **F2.** A folder on no row of the map gets one line that says so, and nothing else. *(the user, 2026-11-20)*
- **F3.** The hook gives no instructions file text: the nested-instructions hook gives that when Claude first touches a subfolder. *(the user, 2026-11-20)*
- **F4.** The hook never blocks the add. If it fails, the folder still loads. *(the user, 2026-11-20)*
- **F5.** The hook records each added folder for the session, so the nested-instructions hook and the folder pane know which folders are added. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
