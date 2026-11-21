# folder-status: the status line groups an added folder under its project

## Covers

- `scripts/statusline-folders.sh`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the folder `$T/mapped`. Write `$T/map.md` with one row: project `shop`, folder `$T/mapped`, as in `tests/e2e/project-map/map-and-commit-check.md`.

## Steps

1. In `$T/h`, run `bash tests/global/folder-status/test-folder-status.sh`.
2. Pipe `{"session_id": "s1", "workspace": {"added_dirs": ["$T/mapped"]}}` to `PROJECT_MAP=$T/map.md CLAUDE_MULTI_FOLDER_STATE=$T/st bash $T/h/scripts/statusline-folders.sh`.
3. Pipe `{"session_id": "s2", "workspace": {"added_dirs": []}}` the same way.

## Expected

1. Step 1 exits 0, and prints no line that starts with `not ok`.
2. Step 2 prints one line, `+ shop(mapped)`.
3. `$T/st/s1/dirs` holds the one line `$T/mapped`.
4. Step 3 prints nothing, and `$T/st/s2/dirs` is empty.

## Cleanup

1. Delete `$T`.
