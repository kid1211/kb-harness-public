---
name: worktree-sync
description: Rebase the current git worktree branch onto the latest origin/main.
when_to_use: Use when the user asks to sync, update, or catch up a worktree with main — "sync this worktree", "catch up with main", "rebase onto main", "pull the latest main in here". Only applies inside a linked git worktree; the script itself refuses (and does nothing) when run from the primary checkout, so it is safe to invoke speculatively.
user-invocable: true
---

# Sync a worktree onto main

Run `scripts/sync.sh` from the current directory:

```sh
bash .claude/skills/worktree-sync/scripts/sync.sh
```

It fetches `origin/main` and rebases the current branch onto it. It never
touches the local `main` ref and never auto-stashes, auto-aborts, or forces
anything — every stop point below leaves the tree exactly as it found it.

Interpret the exit code:

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Not inside a linked worktree | Report it and stop — this only runs inside a worktree. |
| 1 | Working tree is dirty | Tell the user; ask them to commit or stash by hand. Do not stash for them. |
| 2 | `git fetch origin main` failed | Report the git error printed on stderr (network, remote, auth). |
| 3 | Rebase hit a conflict | Report the conflicted files printed on stderr. The rebase is left in progress — resolve by hand (`git rebase --continue`) or ask the user how to proceed. Do not run `--abort` on their behalf without asking. |
| 4 | Rebased cleanly | Report what was rebased (printed on stdout). |

Each of these five outcomes, and the guard order that produces them, is
specified in `model.qnt` — read it only if you're changing this skill's
behavior, not to run it.
