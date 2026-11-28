# Project map: design

## State transitions

Model: [project-map.qnt](project-map.qnt).

```graph
import-graph: architecture.md
```

1. [asked](#asked): a caller runs `scripts/project-map.py` with `folders <project>`, `project <path>`, `check <path>` or `list`.
2. [read](#read): the script read the map page.
3. [folders](#folders): the project is on the map.
4. [project](#project): a folder of the map holds the path.
5. [fallback](#fallback): no folder of the map holds the path.
6. [listed](#listed): the call was `list`, or the project is not on the map.
7. [no_map](#no_map): the map is missing, or holds no table.
8. [checked](#checked): the call was `check`, and a folder of the map holds the path.
9. [unmapped](#unmapped): the call was `check`, and no folder of the map holds the path.

## State deep dive

### asked

A caller runs the script. The map is `$PROJECT_MAP`, else `projects-mapping.md` in the main checkout of the harness that holds the script. Git ignores it. A worktree finds it through `git rev-parse --git-common-dir`. `projects-mapping.md.template` is the tracked start of it. A relative path becomes absolute first. A call in no other form prints the usage and exits 64.

**Invariants:** none.

**Expected output:** none yet.

### read

The script reads the first Markdown table of the page whose header has `Project` and `Folder`. Each row is one folder. A `~` in a folder path stands for the home folder. A row with fewer cells than the header is skipped.

**Invariants:** none.

**Expected output:** the rows, in memory.

### folders

**Invariants:** `foldersMatch`.

**Expected output:** each folder of the project, one full path per line, in the order of the page. Exit 0.

### project

The folder that holds the path is the longest folder of the map that is the path or a parent of it.

**Invariants:** `projectMatch`.

**Expected output:** one line, the project name. Exit 0.

### fallback

**Invariants:** `unknownFallsBack`.

**Expected output:** one line, the name of the last folder of the path. For a file, the name of the folder that holds it. Exit 0.

### listed

**Invariants:** none.

**Expected output:** for `list`, one line per project with its folders. For an unknown project, the line `unknown project: <name>` on stderr, then one project name per line, and exit 1.

### no_map

**Invariants:** `noMapPrintsNothing`.

**Expected output:** `no project map: <path>` on stderr, nothing on stdout, exit 2.

### checked

**Invariants:** `checkedQuiet`.

**Expected output:** nothing. Exit 0.

### unmapped

**Invariants:** `unmappedNamesFolder`.

**Expected output:** `not on the map: <path>` on stderr. Exit 1.

The `commit_hook` node is `.claude/hooks/project-map-check.sh`. It runs after each Bash call that holds `git commit`. It takes the folder of `git -C <dir>`, else the `cwd` of the call, and its git top folder. Then it runs `check` on it:

- `no_map` (exit 2): it tells Claude to copy `projects-mapping.md.template` to `projects-mapping.md` in the harness main checkout, and to ask the user for a row of each folder.
- `unmapped` (exit 1): it tells Claude to ask the user for the project, role and KB of the folder, and to add its row.
- `checked` (exit 0): it prints nothing.

It never blocks the commit.

## Build checks

Unit tests: `tests/global/project-map/test-project-map.sh`, on a throwaway map page.

| Check | Holds |
|---|---|
| `folders shop` prints both folders, in page order | `foldersMatch`, `foldersTest` |
| `project <file deep in a folder>` prints its project | `projectMatch`, `projectTest` |
| a nested folder wins over its parent, the longest match | `projectMatch`, `nestedTest` |
| `project /tmp/other` prints `other` | `unknownFallsBack`, `fallbackTest` |
| `project /tmp/other/a.ts` prints `other`, and `project .` prints the folder name | `unknownFallsBack`, `fallbackTest` |
| a short row is skipped | expected output of `read` |
| `folders nope` lists the projects and exits 1 | `unknownProject`, `unknownTest` |
| `list` prints one line per project with its folders | `list`, `listTest` |
| a missing page exits 2 and prints nothing on stdout | `noMapPrintsNothing`, `noMapTest` |
| `~` in a folder path expands | expected output of `read` |
| `check` of a folder on the map is quiet, exit 0 | `checkedQuiet`, `checkedTest` |
| `check` of a folder on no row names it, exit 1 | `unmappedNamesFolder`, `unmappedTest` |
| `check` with no map exits 2 | `checkNoMapTest` |
| with no `PROJECT_MAP`, the script reads `projects-mapping.md` of the main checkout, also from a worktree | F4 |
| the hook: a commit in a folder on no row adds context that names it, no map adds the set-up context, a mapped folder and a call with no commit print nothing | F5 |
| the hook passes a commit in a repo that holds a row and has none of its own; `domains` gives each domain with its folders and roles as JSON | F6 |

## Coverage

| Want | Held by |
|---|---|
| F1 | the map page, `list`, `noMap`, `noMapPrintsNothing` |
| F2 | `folders`, `project`, `foldersMatch`, `projectMatch` |
| F3 | `fallback`, `unknownFallsBack` |
| F4 | not in the model, a path rule: the default-path test and the `.gitignore` line |
| F5 | `checked`, `unmapped`, `checkedQuiet`, `unmappedNamesFolder`, and the hook tests |
| F6 | not in the model, a hook rule: `tests/global/project-map/test-split-kb.sh` |
| checked | `checkedTest` |
| unmapped | `unmappedTest` |
| folders | `foldersTest` |
| project | `projectTest`, `nestedTest` |
| fallback | `fallbackTest` |
| listed | `listTest`, `unknownTest` |
| no_map | `noMapTest` |
| negative control | `neverFolders`: the checker finds a trace to `folders` |
| start and end | `initWith` sets the call, `done` keeps the end state |

## Risks

- The page has two tables, or the user renames a column. The script reads the first table with a `Project` and a `Folder` header, and ignores the other columns.
- A path with a link in it, such as a KB media folder. The script compares paths as written and after `realpath`, so both forms match.
- The map holds paths of this machine only. Git ignores it, so no commit and no public release holds it.
- A worktree has no copy of a file git ignores. The script reads the map of the main checkout, so each worktree reads the same map.

## Appendix

- The research of the parent level: `personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md`.
