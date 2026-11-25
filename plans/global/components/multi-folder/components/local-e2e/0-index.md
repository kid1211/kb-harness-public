# Local e2e

## Goal

Three test folders next to the harness, in the shape of a real setup: a folder A that holds two code repos, a folder B that is one code repo, and a KB. One command makes them, and one e2e script starts real claude sessions on them through project-start and checks what loads. The user and Claude run it by hand while they build the multi-folder parts.

Route: poc
Builds: `scripts/multi-folder-fixture.sh`, `tests/global/multi-folder-e2e/e2e.sh`, `tests/e2e/multi-folder/local-e2e.md`
Uses: `scripts/project-start.sh`, the `claude` CLI with `-p`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-23: "you can create these 3 test_folders right next to the harness", "write the e2e for that to check", "use that as testing for locally when you develop".

- **F1.** One command makes three test folders in `~/second-brain/test-folders/`: `folder-a` that holds two code repos, `folder-b` that is one code repo, and `kb` that is a KB. Each code repo has its own skill and a `CLAUDE.md` in a subfolder. A run again makes them fresh. *(the user, 2026-11-23)*
- **F2.** The test folders have their own project map, so the e2e never reads or changes the real `projects-mapping.md`. *(Claude, 2026-11-23)*
- **F3.** One e2e script starts real `claude -p` sessions through `project-start.sh` on the test folders. It checks which skills and instructions load, and that a worktree session works. It prints one `ok` or `not ok` line per check. *(the user, 2026-11-23)*
- **F4.** Nothing runs the e2e on its own: the user or Claude runs it by hand while building. Each run costs a few cheap model calls. *(Claude, 2026-11-23)*

## Open questions

TBD

## Research questions

### the user

TBD

### Claude

TBD
