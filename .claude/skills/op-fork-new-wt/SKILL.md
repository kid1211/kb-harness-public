---
name: op-fork-new-wt
description: Fork this Claude session into a new cmux pane, in a new worktree from origin/main that the fork owns.
disable-model-invocation: true
---

Plan: `plans/op-skills/`.

Run `bash <this skill's base directory>/../op-fork-keep/scripts/fork.sh --new-wt`. Relay its one line of output to the user. Read no other file and run no other command.
