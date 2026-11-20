# Project map

## Goal

One page in the `personal` KB maps each folder to its project and its KB. A script reads it, so Claude, the status line and the project start look it up fast.

Route: poc

Builds: `scripts/project-map.py` (look-up by project or by folder), `tests/global/project-map/`, and the map page `claude-research/projects.md` in the `personal` KB
Uses: the `personal` KB, the `kb` skill (where a KB file goes)

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, from the parent level `plans/global/components/multi-folder/`.

- **F1.** A page lists each folder with its project, its KB, and a short note on what it holds. *(the user, 2026-11-19)*
- **F2.** Claude finds the folders of a project, and the project of a folder, with one command. *(the user, 2026-11-19)*
- **F3.** A folder that is not on the map shows as its own folder name, with no error. *(the user, 2026-11-19)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
