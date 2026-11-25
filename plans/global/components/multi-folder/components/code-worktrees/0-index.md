# Code worktrees

## Goal

project-start can start a session on a worktree of each code folder of a project, in place of its main checkout. So two sessions on one project do not edit the same files, and each worktree's own skills and instructions load.

Route: poc
Builds: `scripts/project-start.sh` (the `--worktree` flag), `scripts/project-map.py` (the `roles` look-up), `tests/global/project-start/test-code-worktrees.sh`
Uses: git worktrees, `scripts/project-map.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-23: "if we are working on different worktree of folder A".

- **F1.** `project-start.sh <project> --worktree <name>` adds, for each code repo of the project, the worktree `<repo>/.claude/worktrees/<name>` on branch `<name>`, in place of its main checkout. It makes the worktree if it is missing, and reuses it if it exists. *(the user, 2026-11-23)*
- **F2.** A folder with the role `KB` stays on its main checkout. A folder that is not a git repo is added as it is. *(Claude, 2026-11-23)*
- **F3.** The worktree folder goes into the repo's own `.git/info/exclude`, so the repo's `git status` stays clean and no tracked file changes. *(Claude, 2026-11-23)*
- **F4.** The script never deletes a worktree or a branch. It prints the folders it added. *(Claude, 2026-11-23)*

## Open questions

TBD

## Research questions

### the user

TBD

### Claude

TBD
