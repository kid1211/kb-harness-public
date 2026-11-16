---
title: How to fork a session into a pane
related-requirements: [../0-index.md#R1, ../0-index.md#R2, ../0-index.md#R3, ../0-index.md#R4, ../0-index.md#R5]
related-plan:
  - ../0-index.md
last-updated: 2026-10-18
---

# How to fork a session into a pane

This file finds out how `op-fork` can fork a session, where the fork runs, and how it opens in a cmux pane, for the level `plans/op-skills`. The tests ran on 2026-10-18 with Claude Code 2.1.303. Each one ran in a throwaway git repo in the scratchpad, or in the user's own cmux window.

## Q1. Does a fork keep the conversation, and where does it run?

- **Requirement:** R3
- **Kind:** fact
- **Status:** yes
- **Confidence:** 5. The user's test and two headless tests agree, and anyone can run the commands again.

Yes. `claude --resume <id> --fork-session` starts a new session with a new ID and the whole conversation [1][2]. The fork runs in the directory where you start it, and its transcript goes into the folder of that directory under `~/.claude/projects/` [2][3]. It keeps the session name, so two sessions show the same name [1]. `-n <name>` sets a new name [4].

A fork started without `-w` in the session's own worktree runs in the **same** worktree [1]. The two sessions then share the files, the git index and the branch.

**Correction, 2026-10-18.** An earlier reply in this conversation said that `--resume` finds a session only from the folder the session ran in. That is wrong. A fork started from a different folder kept the whole conversation [3]. `--continue` looks at the current folder [4]. So `op-fork` does not need to start in the session's folder to find the session. It must start there only to run in that folder.

## Q2. Does `--resume <id> --fork-session -w <name>` start the fork in a new worktree?

- **Requirement:** R3
- **Research:** whether `claude --resume <id> --fork-session -w <name>` starts the fork inside the new worktree.
- **Kind:** fact
- **Status:** yes
- **Confidence:** 5. A command anyone can run again shows it.

Yes. The three flags work together. The fork got a new ID and the conversation, git listed the new worktree `.claude/worktrees/<name>` on the branch `worktree-<name>`, and the fork's transcript went into that worktree's folder [5]. Git marks the worktree `locked` while a session holds it [5].

It also works from inside a linked worktree, which is the case of R3. A fork started in the linked worktree `.claude/worktrees/lw` kept the conversation. Its new worktree went into the **main** checkout's `.claude/worktrees/`, not under `lw` [10].

## Q3. Which commit does the worktree of `-w` start from?

- **Requirement:** R3
- **Kind:** fact
- **Status:** done
- **Confidence:** 5. Two runs of one command, with only the setting changed, show it.

By default it starts from `origin/<default branch>`, not from the session's branch. The session was on `feat`, one commit ahead of `main`, and the worktree started at `main commit` [5]. With the setting `"worktree": {"baseRef": "head"}`, the worktree started at `feat commit`, the session's HEAD [6]. From inside a linked worktree, `baseRef: head` started the new worktree at the linked worktree's own HEAD, `lw commit`, not at the main checkout's HEAD [10].

Uncommitted changes do not come across. A file that was not committed in the linked worktree was not in the new worktree [10].

## Q4. Which cmux commands open a new pane and start a command in it, and how does a skill know it runs in cmux?

- **Requirement:** R2
- **Research:** which `cmux` commands open a new pane and start a command in it, and how a skill knows that it runs inside cmux.
- **Kind:** fact
- **Status:** done
- **Confidence:** 5. The commands ran in the user's cmux window, and anyone can run them again.

1. `cmux new-split right --focus false` opens a new terminal pane next to the caller. It prints the new surface, for example `OK surface:101 workspace:13` [7].
2. The new pane starts in the caller's directory. Its prompt showed the `fork` worktree and the branch `worktree-fork` [7].
3. `cmux send --surface surface:101 '<command>\n'` types the command into that pane and runs it [7].
4. `cmux read-screen --surface surface:101 --lines 5` returns the pane's text, so a check can see that the command ran [7].
5. `cmux close-surface --surface surface:101` closes it. Then `cmux list-pane-surfaces` no longer listed it [7].

A session inside cmux has the environment variables `CMUX_SURFACE_ID`, `CMUX_WORKSPACE_ID` and `CMUX_SOCKET_PATH` [8]. `cmux identify` names the caller's pane and surface [7].

## Q5. Same worktree or new worktree for the fork of a session in a worktree?

- **Requirement:** R3
- **Kind:** design
- **Status:** done
- **Confidence:** 4. Each option is tested, B also from inside a linked worktree [10]. The choice is the user's, so it is also in the Open questions.

### Option A: same worktree

- **Pros:** it works now, with no setting [1]. The fork sees the uncommitted changes of the session. One command: `claude --resume <id> --fork-session`.
- **Cons:** the two sessions share the files, the git index and the branch. If both edit or commit at the same time, they overwrite each other.
- **Better when:** the fork only reads, asks or reviews, and one session edits.

### Option B: new worktree from the session's HEAD

- **Pros:** each session has its own files and branch, so neither overwrites the other [5]. With `baseRef: head` the files match the conversation the fork carries [6].
- **Cons:** it needs the `baseRef` setting, or the worktree starts from `origin/main` [5]. Uncommitted changes do not come across (Q3). A new branch must be merged later.
- **Better when:** both sessions edit.

**Recommendation:** B, with `--settings '{"worktree":{"baseRef":"head"}}'` on the fork command. A fork exists to work on its own, and A lets two sessions overwrite each other. If the session has uncommitted changes, `op-fork` says so before it forks.

**Decision:** The user chose A on 2026-10-18 (R7). On 2026-10-20 they kept A as `op-fork-keep` and added a variant of B as `op-fork-new-wt` (R23). It starts from `origin/main`, the default of `-w`, not from the session's HEAD. See [Open questions](../0-index.md#open-questions).

## Q6. Which files does an `op-fork` run write that a state check can read?

- **Requirement:** R5
- **Research:** which files an `op-fork` run writes that a state check can read, and how an output check sees which folder a VS Code window has open.
- **Kind:** fact
- **Status:** open
- **Confidence:** 2. The `op-fork` part is tested. The VS Code part is not found.

For `op-fork`, three things show the state of a run:

- a new transcript `<new id>.jsonl` in the folder of the fork's directory under `~/.claude/projects/` [2][5],
- with `-w`, a new line in `git worktree list` [5],
- a new surface in `cmux list-pane-surfaces`, and its text from `cmux read-screen` [7].

The transcript appears only after the fork's first message [1]. A state check that runs at once can miss it.

Not found: how a script sees which folder a VS Code window has open. `code --status` printed no window or folder line [9]. This part stays open.

## Q7. Can a skill find the session ID and whether it runs in a linked worktree?

- **Requirement:** R1
- **Kind:** fact
- **Status:** yes
- **Confidence:** 5. Commands anyone can run again show it.

Yes. The environment variable `CLAUDE_CODE_SESSION_ID` holds the ID of the session that runs the command [8][11]. In a linked worktree, `git rev-parse --git-dir` prints `.git/worktrees/<name>` and `--git-common-dir` prints the main `.git`, so the two differ [10]. `/status` is a slash command that the user types in the prompt. No tool of Claude's runs it, so the skill uses these two instead.

## Q8. Does `code <path>` open VS Code at a worktree root?

- **Requirement:** R4
- **Kind:** fact
- **Status:** yes
- **Confidence:** 4. The user ran it once and saw the window. The case of a folder outside git is not tested.

Yes. The user ran `code ~/second-brain/harness/.claude/worktrees/fork`. VS Code opened a window on that folder, with the branch `worktree-fork` in its status bar [12]. Not tested: a plain repo root, and a folder that is not in git.

## Sources

1. The user's test, 2026-10-18 22:31 to 22:45 EDT: `claude --resume 28239cb8-8a02-46c9-966d-db21c1f47ae7 --fork-session`, run in `.claude/worktrees/fork`. The fork got the ID `f9f2b330-…`, the same cwd, the same name, and the whole conversation. Answer from the user.
2. The command: `ls ~/.claude/projects/-Users-<user>-second-brain-harness--claude-worktrees-fork/`, run 2026-10-18. It lists `28239cb8-….jsonl` and `f9f2b330-….jsonl`.
3. The command, in a folder that is not the session's: `claude --resume <id> --fork-session -p "Quote my very first message to you, exactly." --model haiku --output-format json --settings '{"disableAllHooks":true}'`, run 2026-10-18. It answered `"say ok"` with a new ID, and its transcript went into that folder's `~/.claude/projects/` entry.
4. The command: `claude --help`, Claude Code 2.1.303, run 2026-10-18. It describes `--fork-session`, `-w, --worktree [name]`, `-n, --name`, and `-c, --continue` as "the most recent conversation in the current directory".
5. The commands, in a throwaway repo with a bare `origin`, `main` and a branch `feat` one commit ahead: `claude --resume <id> --fork-session -w wt1 -p "…" --output-format json --settings '{"disableAllHooks":true}'`, then `git worktree list` and `git -C .claude/worktrees/wt1 log -1`, run 2026-10-18.
6. The same command as [5] with `-w wt2` and `--settings '{"disableAllHooks":true,"worktree":{"baseRef":"head"}}'`, then `git -C .claude/worktrees/wt2 log -1`, run 2026-10-18. It printed `feat commit`.
7. The commands, in the user's cmux window: `cmux new-split right --focus false`, `cmux send`, `cmux read-screen`, `cmux close-surface`, `cmux list-pane-surfaces`, `cmux identify`, run 2026-10-18.
8. The command: `env | grep -i cmux`, in a Claude session inside cmux, run 2026-10-18.
9. The command: `code --status`, run 2026-10-18. It printed no line with "window" or "folder".
10. The commands, in the throwaway repo of [5]: `git worktree add -b lw .claude/worktrees/lw feat`, an uncommitted `dirty.txt` and a commit `lw commit` in it, `git rev-parse --git-dir` and `--git-common-dir`, then from `lw`: `claude --resume <id> --fork-session -w wt3` and `-w wt4` with `--settings '{"disableAllHooks":true,"worktree":{"baseRef":"head"}}'`, then `git worktree list`, `git -C <wt4> log -1` and `ls -A <wt4>`, run 2026-10-18. `wt4` started at `lw commit` and held only `.git`.
11. The command: `echo $CLAUDE_CODE_SESSION_ID`, run 2026-10-18 in the session `f9f2b330-…`. It printed that ID.
12. The user's run of `code ~/second-brain/harness/.claude/worktrees/fork`, 2026-10-18 about 19:00 EDT, and their screenshots of the window and its status bar. Answer from the user.
