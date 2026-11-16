# Op skills: design

## State transitions

Model: [op-skills.qnt](op-skills.qnt), module `opSkills`.

```graph
import-graph: architecture.md
```

1. **Start:** The user runs a skill. Its script reads the facts, then goes on or stops (`factMissing`, `startFork`, `notInCmux`). [Deep dive](#start)
2. **Forking:** a fork skill sends the fork command to a new split pane (`forkOk`, `commandFailed`). [Deep dive](#forking)
3. **Forked:** the fork runs in its pane. [Deep dive](#forked)
4. **Fact missing:** a fact is missing. [Deep dive](#fact_missing)
5. **Not in cmux:** the session is not in cmux. [Deep dive](#not_in_cmux)
6. **Command failed:** a `cmux` or `claude` command failed. [Deep dive](#command_failed)

The two skills are one machine with a `kind`: `keep` and `newwt`. They share `fork.sh`, and `op-fork-new-wt` runs it with `--new-wt`. The two skills are already built, so this design describes them.

## State deep dive

### Start

The `SKILL.md` of each skill runs one script and reads nothing else. The script finds the facts from the environment and git, not from `/status`.

- The session ID (`CLAUDE_CODE_SESSION_ID`), the directory (`pwd -P`), and whether the session runs in cmux (`CMUX_SURFACE_ID` and the `cmux` command). With `--new-wt`, also the main checkout from `git rev-parse --git-common-dir`.
- **Invariants:** `failLeavesNothing`.
- **Expected output:** none yet.

### Forking

- The script counts panes, fork processes, worktrees and branches. It opens a split pane with `cmux new-split right --focus false`, and sends `cd <dir> && claude --resume <id> --fork-session` to it. `op-fork-new-wt` adds `-w fork-<8 characters of the ID>`, or `-2`, `-3` if that name is in use.
- It waits up to 10 seconds for the state check to say `forked`.
- **Invariants:** `onePane`, `worktreeOnlyNewWt`.
- **Expected output:** none yet.

### Forked

- **Invariants:** `onePane`, `worktreeOnlyNewWt`.
- **Expected output:** one line. `op-fork-keep`: `op-fork-keep: forked into <surface>, in <dir>`. `op-fork-new-wt`: `... in the new worktree <path> from origin/main`.

### Fact missing

- **Invariants:** `failLeavesNothing`.
- **Expected output:** `<skill>: no session ID (CLAUDE_CODE_SESSION_ID is not set). Nothing opened.` or `... is not in a git repo. Nothing opened.`, exit 1.

### Not in cmux

- **Invariants:** `failLeavesNothing`.
- **Expected output:** `<skill>: this session is not inside cmux. Nothing opened. Run by hand: <fork command>`, exit 1.

### Command failed

- The script closes the pane it opened with `cmux close-surface`. It removes the worktree and branch that `claude -w` made, if the name it chose is now in use. Then it runs the output check with `nothing`.
- **Invariants:** `failLeavesNothing`.
- **Expected output:** `<skill>: <what failed>. Run by hand: <command>`, exit 1.

## Build checks

Both skills are built. The tests exist: `tests/skills/op-fork/test-op-fork.sh`. They use a stub `cmux` and `claude`.

| Check | Holds |
|---|---|
| `fork.sh` and `check-state.sh`, the state check: forked, nothing, partial | R25, `onePane` |
| `check-output.sh` of `op-fork-keep`: one new pane and process, no new worktree or branch | R7, R25, `worktreeOnlyNewWt` |
| `op-fork-new-wt` run: one new worktree and branch named `fork-<8>` | R23, R25, `worktreeOnlyNewWt` |
| a run outside cmux opens nothing and prints the command | R11, `failLeavesNothing` |
| a failed `cmux send` or `claude` closes the pane and removes a worktree and branch that `claude -w` made | R11, `failLeavesNothing` |
| no session ID: nothing opens, the fact is named | R24, `failLeavesNothing` |
| a run in a linked worktree, in the main checkout, and after the session entered a worktree | R20 |
| each `SKILL.md` runs one script and tells Claude to read no other file | R14 (text rule, no model) |

The negative control `neverForked` must fail. The state check is `C flow`: the built `SKILL.md` of each skill is short and has no heading per state, so `C flow` prints a `DRIFT` line for each state.

No check can see:

- whether a new pane starts in the right folder. The `cd` in the command covers it, and the test checks the command text.

## Coverage

| Requirement | Held by |
|---|---|
| R24 | `factMissing`, `failLeavesNothing`, `factTest`, and the no-session-ID test |
| R11 | `startFork`, `notInCmux`, `commandFailed`, `failLeavesNothing`, `onePane`, `noCmuxTest`, `failTest` |
| R7 | `forkOk`, `worktreeOnlyNewWt`, `keepTest` |
| R23 | `forkOk`, `worktreeOnlyNewWt`, `newWtTest`. The name `-2`, `-3` and the base `origin/main` are held by the shell test, not the model |
| R25 | The checks of Build checks. The model holds the four end states, with one test each (the last four rows) |
| R20 | Not in the model: where the session is does not change a state. The shell tests run it in a linked worktree and in the main checkout |
| R14 | Not in the model: it is a rule on the text of each `SKILL.md` and the output of each script. The shell tests count the output lines |
| forked | `keepTest`, `newWtTest` |
| fact_missing | `factTest` |
| not_in_cmux | `noCmuxTest` |
| command_failed | `failTest` |

`initWith` sets the start for the skill the user chose. `done` keeps an ended state as it is (R25).

## Risks

- **A fork of `op-fork-new-wt` starts from `origin/main`.** Changes of the session that are not on `main` do not come across. The skill's line says so.
- **The state check passes `-w` runs on either folder.** The `claude` process may report its start folder or the new worktree. `check-state.sh` accepts both and has a `ponytail:` note. The folder after `-w` is not tested live.
- **The model has no worktree states.** After R7, a fork acts the same in a worktree and outside one. R20 is held by the shell tests only.
- **No `C flow` match.** The `SKILL.md` of each skill must stay short (R14), so it holds no heading per state. `C flow` prints `DRIFT` lines. They are for `p-build` to accept.

## Appendix

- Research: [fork-session.md](research/fork-session.md), Q2, Q3 and Q5.
- Scripts: `.claude/skills/op-fork-keep/scripts/`.
