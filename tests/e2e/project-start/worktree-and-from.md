# project-start: --worktree adds a worktree of each code repo, and --from finds the project of a folder

## Covers

- `scripts/project-start.sh`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the git repo `$T/web` with one commit, the folder `$T/web/src/lib`, and the git repo `$T/kb` with one commit.
4. Write `$T/map.md` with the header `| Project | Folder | Role |` and two rows: project `shop`, folder `$T/web`, role `code`, and project `shop`, folder `$T/kb`, role `KB`.
5. Write a stub `$T/bin/claude` that prints `arg=<a>` for each argument. Make it executable.

## Steps

1. In `$T/h`, run `bash tests/global/project-start/test-code-worktrees.sh` and `bash tests/global/project-start/test-from-folder.sh`.
2. Run `PATH=$T/bin:$PATH PROJECT_MAP=$T/map.md bash $T/h/scripts/project-start.sh shop --worktree e2e -p hi`.
3. Run step 2 again.
4. Run `PATH=$T/bin:$PATH PROJECT_MAP=$T/map.md bash $T/h/scripts/project-start.sh --from $T/web/src/lib`.
5. Make the folder `$T/x`, and run step 4 with `--from $T/x`. Keep its exit code.

## Expected

1. Each script of step 1 exits 0, and prints no line that starts with `not ok`.
2. Step 2 prints `arg=$T/web/.claude/worktrees/e2e` and `arg=$T/kb`, and no `arg=$T/web`. It ends with `arg=-p` and `arg=hi`.
3. After step 2, `git -C $T/web/.claude/worktrees/e2e branch --show-current` prints `e2e`, `$T/kb/.claude/worktrees` does not exist, and `git -C $T/web status --porcelain` prints nothing.
4. Step 3 exits 0 and prints the same folders: it reuses the worktree.
5. Step 4 prints `arg=$T/web` and `arg=$T/kb`, and no `arg=$T/web/src/lib`.
6. Step 5 exits 1, prints `not on the map: $T/x`, and prints no `arg=` line.

## Cleanup

1. Delete `$T`.
