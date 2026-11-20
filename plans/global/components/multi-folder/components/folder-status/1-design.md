# Folder status: design

## State transitions

Model: [folder-status.qnt](folder-status.qnt).

```graph
import-graph: architecture.md
```

1. [input](#input): the status line pipes its JSON into `scripts/statusline-folders.sh`.
2. [quiet](#quiet): `workspace.added_dirs` is empty or missing.
3. [group](#group): the session has one or more added folders.
4. [shown](#shown): the script printed the part.

## State deep dive

### input

`~/.claude/statusline.sh` runs the script on each update, with the same JSON it reads.

**Invariants:** none.

**Expected output:** none yet.

### quiet

**Invariants:** `quietWhenNone`, `recordedAll`.

**Expected output:** nothing, exit 0. The status line looks as it does now. The session file is empty.

### group

The script runs `scripts/project-map.py project <folder>` once per added folder. A folder on no row gets its own folder name back, and counts as a folder with no project.

**Invariants:** none.

**Expected output:** the project of each folder, in memory.

### shown

**Invariants:** `eachFolderShown`, `projectOnce`, `recordedAll`.

The session file is `${CLAUDE_MULTI_FOLDER_STATE:-~/.claude/multi-folder}/<session_id>/dirs`, one added folder per line. The script writes it only when the input has a `session_id`.

**Expected output:** one line: `+ ` then one entry per group, joined by two spaces. A project group is `<project>(<name>,<name>)`, with the last folder name of each of its folders. A folder on no row is its own name. The entries keep the order of `added_dirs`.

## Build checks

Unit tests: `tests/global/folder-status/test-folder-status.sh`, with a throwaway map in `PROJECT_MAP`.

| Check | Holds |
|---|---|
| no `added_dirs`, or an empty one, prints nothing | `quiet`, `quietWhenNone`, `noneTest` |
| two folders of one project print the project once, with both names | `group`, `show`, `projectOnce`, `twoFoldersTest` |
| a folder on no row prints its own name | `eachFolderShown` |
| the line starts with `+ ` | expected output of `shown` |
| the session file holds the added folders, and is empty with none | `recordedAll` |

## Coverage

| Want | Held by |
|---|---|
| F1 | `show`, `eachFolderShown` |
| F2 | `group`, `projectOnce`, `twoFoldersTest` |
| F3 | `quiet`, `quietWhenNone`, `noneTest` |
| F4 | `show`, `quiet`, `recordedAll`, `twoFoldersTest` |
| shown | `twoFoldersTest` |
| quiet | `noneTest` |
| negative control | `neverTwoInOne`: the checker finds the shop group with two folders |
| start and end | `initWith` sets the added folders, `done` keeps the end state |

## Risks

- The session files stay in `~/.claude/multi-folder/` after a session ends. They are small. Delete the folder at any time.
- The status line runs often. The script calls `project-map.py` once per added folder, so two or three folders cost under 0.2 s.
- `~/.claude/statusline.sh` is not in the harness. `mac-setup/claude-code-setup.md` names the line that calls this script, so a new Mac gets it back.
- The docs say `added_dirs` holds the folders of `--add-dir` and `/add-dir`. A folder from `permissions.additionalDirectories` may not show. Not tested.

## Appendix

- The research of the parent level, Q6: `personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md`.
