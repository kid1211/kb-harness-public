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

**Expected output:** one line, nothing on line 1, exit 0. The session file is empty.

### group

For each added folder, the script finds the top of its checkout (`git rev-parse --show-toplevel`) and its role (`scripts/project-map.py role <folder>`). A folder in no repo has no top.

**Invariants:** none.

**Expected output:** the top and role of each folder, in memory.

### shown

**Invariants:** `eachCodeShown`, `onlyCode`, `domainShown`, `recordedAll`.

The session file is `${CLAUDE_MULTI_FOLDER_STATE:-~/.claude/multi-folder}/<session_id>/dirs`, one added folder per line. The script writes it only when the input has a `session_id`.

**Expected output:** one line, or nothing when no folder is code. Each code folder is `<role> <name>`: the role as a coloured tag, then the folder name of its top. Entries keep the order of `added_dirs`, once each, joined by two spaces. A code folder has a role of `frontend`, `backend`, `mobile`, `infra` or `lib`, and a top. A role off the list (`project-map.py` holds it) shows on a firebrick tag. `~/.claude/statusline.sh` prints the line under its own line.

The script prints that line second. The first line is the domain, or `no domain`. The script writes the domain to the session file `domain` too: `domainsOf`, the largest domains of the map whose folders are all added (`project-map.py selected`), joined by `, `, or an empty file.

## Build checks

Unit tests: `tests/global/folder-status/test-folder-status.sh`, with a throwaway map in `PROJECT_MAP`.

| Check | Holds |
|---|---|
| no `added_dirs`, or an empty one, prints nothing on line 1 and no code line | `quiet`, `quietWhenNone`, `noneTest` |
| a code repo and its worktree show by their own folder names, each with its role tag | `group`, `show`, `eachCodeShown`, `twoFoldersTest` |
| a KB, the harness, and a folder with no role or no repo do not show | `onlyCode`, `twoFoldersTest` |
| with no code folder the script prints nothing | `onlyCode` |
| a role off the list shows on the error tag | `show` |
| `project-map.py role` gives the Role cell of the longest row | `group` |
| the session file `domain` names the largest full domains; the first line is empty | `domainsOf`, `domainShown`, `twoFoldersTest` |
| the session file holds the added folders, and is empty with none | `recordedAll` |

## Coverage

| Want | Held by |
|---|---|
| F1 | `show`, `eachCodeShown` |
| F2 | `group`, `eachCodeShown`, `onlyCode`, `twoFoldersTest` |
| F5 | `show`: the role list and its colours are in the script, the error tag is a unit test |
| F6 | `show`, `domainsOf`, `domainShown`, `twoFoldersTest` |
| F4 | `show`, `quiet`, `recordedAll`, `twoFoldersTest` |
| shown | `twoFoldersTest` |
| quiet | `noneTest` |
| negative control | `neverEmpty`: the checker finds a run with folders added and none shown |
| start and end | `initWith` sets the added folders, `done` keeps the end state |

## Risks

- The session files stay in `~/.claude/multi-folder/` after a session ends. They are small. Delete the folder at any time.
- The status line runs often. The script calls `git` and `project-map.py` once per added folder, so two or three folders cost under 0.2 s.
- `~/.claude/statusline.sh` is not in the harness. `mac-setup/claude-code-setup.md` names the line that calls this script, so a new Mac gets it back.
- The docs say `added_dirs` holds the folders of `--add-dir` and `/add-dir`. A folder from `permissions.additionalDirectories` may not show. Not tested.

## Appendix

- The research of the parent level, Q6: `personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md`.
