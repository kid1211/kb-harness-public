# Point at folder: design

## State transitions

Model: [point-at-folder.qnt](point-at-folder.qnt).

```graph
import-graph: architecture.md
```

1. [asked](#asked): `scripts/project-start.sh --from <folder>` runs.
2. [started](#started): `claude` runs with the folders added.
3. [unmapped](#unmapped): the folder is on no row of the map.

## State deep dive

### asked

`project-start.sh --from <folder> [--worktree <name>] [claude args]`.

**Invariants:** none.

**Expected output:** none yet.

### started

The script finds the project by `scripts/project-map.py check` and `project`, then runs as `project-start.sh <project>`. It also adds the git root of the folder. The root takes the role of the longest map row that holds the folder, by real paths. So `--worktree` works on it as in `code-worktrees`, and a KB repo gets no worktree. A folder in no repo is its own root.

**Invariants:** `startAddsSiblings`, `startAddsRoot`.

**Expected output:** one `added:` line per folder, then `claude`.

### unmapped

**Invariants:** `unmappedAsks`.

**Expected output:** `not on the map: <folder>`, the projects, `Add a row for it to <map path>, with its project, then run this again.`, exit 1, no `claude`.

## Build checks

| Check | Test | Holds |
|---|---|---|
| `--from` a deep folder adds each sibling and the git root, not the folder itself | `tests/global/project-start/test-from-folder.sh` | `start`, `startAddsSiblings`, `startAddsRoot`, `startTest` |
| `--from` a folder on no row exits 1, asks for a row, runs no `claude` | `tests/global/project-start/test-from-folder.sh` | `unmapped`, `unmappedAsks`, `unmappedTest` |
| `--from` with `--worktree` adds the worktree of a code root, and none for a root above a KB row | `tests/global/project-start/test-from-folder.sh` | `start`, `startAddsRoot` |
| a missing map or an empty folder name starts nothing, with its own message | `tests/global/project-start/test-from-folder.sh` | `unmapped` |
| a real session from `--from` has the skills of the siblings | `tests/global/multi-folder-e2e/e2e.sh` | `startTest` |

The user's answer to the map question is not seen by any check.

## Coverage

| Want | Held by |
|---|---|
| F1 | `initWith`, `start`, `startAddsSiblings`, `startTest` |
| F2 | `startAddsRoot`, `startTest` |
| F3 | `unmapped`, `unmappedAsks`, `unmappedTest`, `done` |
| started | `startTest` |
| unmapped | `unmappedTest` |
| negative control | `neverAsksMap`: the checker finds a run that asks for a row |

## Risks

- A skills folder deeper than the git root does not load. Map that repo on its own row.
- In a session, a `/add-dir` of a folder still gets no siblings. Only the start does.

## Appendix

- The user's answers of 2026-11-23: a sibling is a folder of the same project on the map, a new folder asks for its row, and the git root is the top.
