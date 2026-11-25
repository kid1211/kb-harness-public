# multi-folder: real sessions on sub-repos and worktrees of code folders

## Covers

- `scripts/project-start.sh`
- `scripts/project-map.py`
- `scripts/multi-folder-fixture.sh`
- `tests/global/multi-folder-e2e/e2e.sh`

## Setup

1. Run the e2e from the harness checkout you test. It makes `~/second-brain/test-folders/` itself, by `scripts/multi-folder-fixture.sh`.
2. `claude` is on `PATH` and logged in.

## Steps

1. Run `bash tests/global/multi-folder-e2e/e2e.sh`. Keep its exit code.

## Expected

1. It prints `ok - fixture-fresh` and `ok - fixture-keeps-other`.
2. It prints `ok - skill-web`, `ok - skill-api` and `ok - skill-b`: each sub-repo skill loads.
3. It prints `ok - instructions-web`: the `CLAUDE.md` of `folder-a/web/src` reaches Claude.
4. It prints `ok - worktree`: `folder-a/web/.claude/worktrees/e2e` exists, is added, has its skill and its file, and `folder-a/web` has a clean `git status`.
5. It exits 0.

## Cleanup

1. Delete `~/second-brain/test-folders/`, or leave it for the next run, which makes it fresh.
