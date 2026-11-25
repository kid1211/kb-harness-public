# Project map

## Goal

One local file, `projects-mapping.md` in the harness main checkout, maps each folder to its project and its KB. Git ignores it, so it stays on this machine. A script reads it, so Claude, the status line and the project start look it up fast.

Route: poc

Builds: `scripts/project-map.py` (look-up by project or by folder, the check of a folder, the `domains` list and the `selected` domains), `.claude/hooks/project-map-check.sh` (the check after a git commit), `projects-mapping.md.template`, the `projects-mapping.md` line of `.gitignore`, `tests/global/project-map/`
Uses: git

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, from the parent level `plans/global/components/multi-folder/`.

- **F1.** A page lists each folder with its project, its KB, and a short note on what it holds. *(the user, 2026-11-19)*
- **F2.** Claude finds the folders of a project, and the project of a folder, with one command. *(the user, 2026-11-19)*
- **F3.** A folder that is not on the map shows as its own folder name, with no error. *(the user, 2026-11-19)*
- **F4.** The map is a local file, `projects-mapping.md`, that git ignores, not a page in a KB. *(the user, 2026-11-20)*
- **F6.** A KB repo split into domains has rows inside it and none of its own. After a commit in such a repo, the check passes. *(the user, 2026-11-24: "personal is def not a domain")*
- **F5.** After a git commit, a hook checks the map. If the map is missing, it tells Claude to set it up. If the folder of the commit is not on the map, it tells Claude to ask the user to add it. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
