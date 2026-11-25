# Code worktrees: design

## State transitions

Model: [code-worktrees.qnt](code-worktrees.qnt).

```graph
import-graph: architecture.md
```

1. [asked](#asked): the user runs `scripts/project-start.sh <project> --worktree <name>`.
2. [made](#made): each code repo has `<repo>/.claude/worktrees/<name>`.
3. [started](#started): `claude` runs with the worktrees in place of the main checkouts.

## State deep dive

### asked

`--worktree <name>` comes right after the project. The name is one git branch name. The other arguments go to `claude`.

**Invariants:** none.

**Expected output:** none yet.

### made

A folder is a code repo when `git -C <folder> rev-parse --show-toplevel` prints the folder itself, and its map role is not `KB`. The role comes from `scripts/project-map.py roles <project>`, one `<folder>\t<role>` line per row. For each code repo:

- If `<repo>/.claude/worktrees/<name>` exists, the script reuses it.
- Else it runs `git -C <repo> worktree add <repo>/.claude/worktrees/<name> -b <name>`, or with no `-b` if the branch exists.
- It adds `.claude/worktrees/` to `<repo>/.git/info/exclude` if that line is not there.

**Invariants:** `excludedEach`, `neverDeletes`.

**Expected output:** a failed `git worktree add` names the repo and stops the script before `claude`.

### started

**Invariants:** `noMainOfCode`, `kbAndPlainKept`.

**Expected output:** one line `added: <folder>` per folder on stderr, then `claude` with one `--add-dir` per folder.

## Build checks

Unit tests in `tests/global/project-start/test-code-worktrees.sh`, with real git repos and a stub `claude`:

| Check | Holds |
|---|---|
| a code repo is added as its worktree, made on branch `<name>` | `make`, `noMainOfCode`, `startTest` |
| a second run reuses the worktree | `startTest` with an existing one |
| a KB row and a folder that is no repo are added as they are | `kbAndPlainKept` |
| `.git/info/exclude` of each code repo names the worktrees folder, and `git status --porcelain` stays empty | `excludedEach` |
| the script deletes nothing | `neverDeletes` |

## Coverage

| Want | Held by |
|---|---|
| F1 | `initWith`, `make`, `noMainOfCode`, `startTest` |
| F2 | `kbAndPlainKept` |
| F3 | `excludedEach` |
| F4 | `start`, `done`, `neverDeletes` |
| started | `startTest` |
| negative control | `noWorktree`: the checker finds a worktree added |

## Risks

- A mapped folder that is no repo but holds repos, such as `folder-a`, is still added as it is, so its main checkouts stay open to edits. Its sub-repos with skills are added as worktrees.
- Nothing cleans up the worktrees. `git -C <repo> worktree remove` does it by hand. A later want can add an end step.
- A worktree branch with the same name in two repos is fine: each repo has its own branches.

## Appendix

- `scripts/project-start.sh` and its design in `../project-start/1-design.md`.
