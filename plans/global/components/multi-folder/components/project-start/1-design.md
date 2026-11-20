# Project start: design

## State transitions

Model: [project-start.qnt](project-start.qnt).

```graph
import-graph: architecture.md
```

1. [asked](#asked): The user runs `scripts/project-start.sh <project>`.
2. [looked](#looked): the script ran `scripts/project-map.py folders <project>`.
3. [unknown](#unknown): the project is not on the map.
4. [check](#check): the script split the folders into those on disk and those missing.
5. [started](#started): `claude` runs in the harness with the kept folders.

## State deep dive

### asked

The user runs the script with one project name. Any extra argument goes to `claude` after the `--add-dir` folders. No name prints the usage, then the projects, and exits 64.

**Invariants:** none.

**Expected output:** none yet.

### looked

**Invariants:** none.

**Expected output:** the folders of the project, from the map.

### unknown

**Invariants:** `unknownAddsNothing`.

**Expected output:** the look-up's `unknown project` line and the projects on stderr. Exit 1. `claude` does not run.

### check

**Invariants:** `addedOnDisk`.

**Expected output:** one line `missing: <folder>` on stderr per folder that is not on disk.

### started

The script changes to the root of its own harness checkout, then runs `exec claude --add-dir <folder> ... [extra args]`. A folder that is the harness itself is left out, since it is the start folder.

**Invariants:** `addedOfProject`, `addedOnDisk`.

**Expected output:** `claude` runs, with the harness as its start folder. The status line names each added folder.

## Build checks

Unit tests: `tests/global/project-start/test-project-start.sh`, with a throwaway map and a stub `claude` on `PATH` that prints its folder and its arguments.

| Check | Holds |
|---|---|
| a known project runs `claude` in the harness with `--add-dir` per folder | `start`, `addedOfProject`, `startTest` |
| a missing folder is named and left out, the others load | `check`, `addedOnDisk`, `startTest` |
| an unknown project exits 1 and does not run `claude` | `unknown`, `unknownAddsNothing`, `unknownTest` |
| extra arguments go to `claude` | expected output of `asked` |
| the harness folder itself is not added | expected output of `started` |

## Coverage

| Want | Held by |
|---|---|
| F1 | `look`, `start`, `addedOfProject`, `startTest` |
| F2 | `unknown`, `unknownAddsNothing`, `unknownTest` |
| F3 | `check`, `addedOnDisk`, `startTest` |
| started | `startTest` |
| unknown | `unknownTest` |
| negative control | `neverAdds`: the checker finds a start with two folders |
| start and end | `initWith` sets the name, `done` keeps the end state |

## Risks

- A project whose folders all are missing starts `claude` in the harness with no folder. The missing lines say why.
- The hooks of an added code repo do not run, by the research. The script cannot change that.
- The script runs from a worktree too. It starts `claude` in that checkout, not in the main one.

## Appendix

- The research of the parent level, Q1 and Q7: `personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md`.
