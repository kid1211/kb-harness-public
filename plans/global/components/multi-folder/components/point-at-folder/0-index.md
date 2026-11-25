# Point at folder

## Goal

The user points at one folder. `project-start.sh --from` adds the git root of the folder, and starts its project on the map with each sibling. The root's own `CLAUDE.md` and the map say which subfolder does what.

Route: poc
Builds: `scripts/project-start.sh` (the `--from` flag), `tests/global/project-start/test-from-folder.sh`, `tests/global/multi-folder-e2e/e2e.sh` (the from-folder check)
Uses: `scripts/project-map.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-23: "look at one folder and all the same sibling load up, and all the Claude md and skill loaded till way up root of the folder". A sibling is "what is in the mapping that belong on the same group, if it is new, it should ask me to define the mapping". The top is the git repo root.

- **F1.** `project-start.sh --from <folder>` starts the project of the folder: each sibling on the map, as `project-start.sh <project>` does, with `--worktree` too. *(the user, 2026-11-23)*
- **F2.** The git root of the folder is added. Nothing below it or above it is looked for: its `CLAUDE.md` and the map say which subfolder does what. *(the user, 2026-11-23: "just find the root of git and add that as add for, and call it a day")*
- **F3.** A folder on no row of the map starts nothing. The script names it, lists the projects, and asks the user to add a row to the map. *(the user, 2026-11-23)*

## Open questions

TBD

## Research questions

### the user

TBD

### Claude

TBD
