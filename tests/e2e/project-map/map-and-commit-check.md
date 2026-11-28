# project-map: a fresh clone looks up the map, and the hook names a folder on no row

## Covers

- `scripts/project-map.py`
- `.claude/hooks/project-map-check.sh`
- `projects-mapping.md.template`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the folders `$T/mapped` and `$T/other`, and run `git init -q $T/other`.
4. Write `$T/map.md` with this table, `$T` written out in full:

   | Project | Folder | Role | KB |
   |---|---|---|---|
   | shop | $T/mapped | code | |

## Steps

1. In `$T/h`, run `bash tests/global/project-map/test-project-map.sh` and `bash tests/global/project-map/test-project-map-check.sh`.
2. In `$T/h`, run `PROJECT_MAP=projects-mapping.md.template python3 scripts/project-map.py list`.
3. Run `PROJECT_MAP=$T/map.md python3 $T/h/scripts/project-map.py check $T/mapped`, then the same with `$T/other`. Keep each exit code.
4. Pipe `{"tool_input": {"command": "git commit -m x"}, "cwd": "$T/other"}` to `PROJECT_MAP=$T/map.md bash $T/h/.claude/hooks/project-map-check.sh`. Keep its exit code.
5. Do step 4 again with `PROJECT_MAP=$T/none.md`, a file that does not exist.
6. Do step 4 again with the command `git status`.

## Expected

1. Both suites of step 1 exit 0, and print no line that starts with `not ok`.
2. Step 2 prints one line that starts with `harness:`.
3. Step 3 exits 0 for `$T/mapped` and prints nothing. It exits 1 for `$T/other` and prints `not on the map:` and that path.
4. Step 4 exits 0, and its JSON `additionalContext` says the folder is not on the project map.
5. Step 5 exits 0, and its `additionalContext` names `projects-mapping.md.template`.
6. Step 6 exits 0 and prints nothing.

## Cleanup

1. Delete `$T`.
