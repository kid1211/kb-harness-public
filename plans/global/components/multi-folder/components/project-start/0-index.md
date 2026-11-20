# Project start

## Goal

One command starts a Claude session in the harness with each folder of a project added by `--add-dir`. The harness hooks then run, and each folder's own skills load.

Route: poc

Builds: `scripts/project-start.sh` and `tests/global/project-start/`
Uses: `scripts/project-map.py`, the `claude` CLI `--add-dir`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, from the parent level `plans/global/components/multi-folder/`.

- **F1.** `project-start.sh <project>` starts `claude` in the harness with each folder of the project added. *(the user, 2026-11-19)*
- **F2.** An unknown project name prints the projects on the map and starts nothing. *(the user, 2026-11-19)*
- **F3.** A folder of the map that does not exist on this machine is named, and the others still load. *(the user, 2026-11-19)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
