# add-dir-context: a folder added by /add-dir is told to Claude once, with its project

## Covers

- `.claude/hooks/add-dir-context.sh`
- `scripts/folder-context.py`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the folders `$T/mapped` and `$T/other`. Write `$T/map.md` with one row: project `shop`, folder `$T/mapped`, role `code`, as in `tests/e2e/project-map/map-and-commit-check.md`.
4. Run each step below with `PROJECT_MAP=$T/map.md CLAUDE_MULTI_FOLDER_STATE=$T/st`.

## Steps

1. In `$T/h`, run `bash tests/global/add-dir-context/test-add-dir-context.sh`.
2. Run `python3 $T/h/scripts/folder-context.py $T/mapped $T/other`.
3. Pipe `{"hook_event_name": "DirectoryAdded", "session_id": "s1", "directory": "$T/mapped"}` to `bash $T/h/.claude/hooks/add-dir-context.sh`.
4. Pipe `{"hook_event_name": "UserPromptSubmit", "session_id": "s1"}` to the same hook.
5. Do step 4 again.

## Expected

1. Step 1 exits 0, and prints no line that starts with `not ok`.
2. Step 2 prints `Folder $T/mapped: project shop, role code.` and `Folder $T/other: on no row of the project map.`
3. Step 3 exits 0 and prints nothing.
4. Step 4 exits 0, and its JSON `additionalContext` names `$T/mapped` with `project shop, role code`.
5. Step 5 exits 0 and prints nothing: each folder is told once.

## Cleanup

1. Delete `$T`.
