# project-start: claude starts in the harness with each folder of the project

## Covers

- `scripts/project-start.sh`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the folder `$T/mapped`. Write `$T/map.md` with one row: project `shop`, folder `$T/mapped`, as in `tests/e2e/project-map/map-and-commit-check.md`.
4. Write a stub `$T/bin/claude` that prints `cwd=$PWD`, then `arg=<a>` for each argument. Make it executable.

## Steps

1. In `$T/h`, run `bash tests/global/project-start/test-project-start.sh`.
2. Run `PATH=$T/bin:$PATH PROJECT_MAP=$T/map.md bash $T/h/scripts/project-start.sh shop -p hi`.
3. Run the same with the project `nope`. Keep its exit code.

## Expected

1. Step 1 exits 0, and prints no line that starts with `not ok`.
2. Step 2 prints `cwd=` and the path of `$T/h`, then `arg=--add-dir`, `arg=$T/mapped`, `arg=-p` and `arg=hi`, in that order.
3. Step 3 exits 1, prints `unknown project: nope`, and prints no `cwd=` line.

## Cleanup

1. Delete `$T`.
