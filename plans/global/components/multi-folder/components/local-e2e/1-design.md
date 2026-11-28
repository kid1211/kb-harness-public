# Local e2e: design

## State transitions

Model: [local-e2e.qnt](local-e2e.qnt).

```graph
import-graph: architecture.md
```

1. [asked](#asked): the user or Claude runs `tests/global/multi-folder-e2e/e2e.sh`.
2. [made](#made): `scripts/multi-folder-fixture.sh` made `~/second-brain/test-folders/`.
3. [ran](#ran): the `claude -p` sessions ran.
4. [reported](#reported): the e2e printed its lines and its exit code.

## State deep dive

### asked

The e2e takes no argument. `MF_FIXTURE` moves the test folders, for a run in a temp folder.

**Invariants:** none.

**Expected output:** none yet.

### made

The fixture script deletes the test folders and makes them again:

- `folder-a/` is not a repo. It holds `web/` and `api/`, each a git repo with one commit, a skill `web-skill` or `api-skill`, and `web/src/CLAUDE.md` with a marker word.
- `folder-b/` is a git repo with a skill `b-skill`.
- `kb/` holds a `CLAUDE.md` and one page.
- `projects-mapping.md` maps the project `mf-test`: `folder-a` and `folder-b` with the role code, `kb` with the role KB.

**Invariants:** `madeFresh`.

**Expected output:** the path of the test folders.

### ran

Each session runs `PROJECT_MAP=<test map> scripts/project-start.sh mf-test -p --model haiku <prompt>`, so the real map is never read. A session asks Claude to list the skills it has and to read `web/src/x.txt`, then to quote the marker word of its instructions. The worktree session adds `--worktree e2e`.

**Invariants:** `neverRealMap`.

**Expected output:** the text of each session.

### reported

**Invariants:** `oneLinePerCheck`.

**Expected output:** one `ok <check>` or `not ok <check>` line for each of `skill-web`, `skill-api`, `skill-b`, `instructions-web` and `worktree`. Exit 0 only if each line is `ok`. A check of a part that is not built yet prints `not ok`, so the e2e shows what is left.

## Build checks

The e2e is the check. It calls a model, so it never runs in `npm run check` or in a hook.

| Check | Holds |
|---|---|
| a run of the fixture script twice leaves the same tree, with no old file | `make`, `madeFresh` |
| the e2e sets `PROJECT_MAP` to the test map | `run_`, `neverRealMap` |
| the e2e prints one line per check | `report`, `oneLinePerCheck`, `reportTest` |

`tests/e2e/multi-folder/local-e2e.md` writes the same test as a test plan, with its Covers, for `public-release/R56`.

## Coverage

| Want | Held by |
|---|---|
| F1 | `initWith` starts with or with no old files, `make`, `madeFresh`, `reportTest` |
| F2 | `run_`, `neverRealMap` |
| F3 | `report`, `oneLinePerCheck`, `reportTest` |
| F4 | not in the model: nothing calls the e2e. No hook or CI names it |
| reported | `reportTest`, `done` |
| negative control | `neverReports`: the checker finds a report |

## Risks

- A model may list skills wrong. The checks look for a skill name or a marker word in the text, not for a sentence.
- Each run costs a few Haiku calls. The e2e is by hand only.
- The sessions start in the harness, so its hooks run. A hook that blocks a `-p` session fails a check, which shows it.

## Appendix

- The test of 2026-11-23 in this session: `--add-dir` of a parent folder loads no skill of a subfolder, and `--add-dir` of the subfolder does.
- The research page `personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md`, Q1 and Q3.
