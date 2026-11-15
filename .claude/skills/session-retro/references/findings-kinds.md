# Kinds of finding

Each finding has one kind from this list. `findings.py check` drops a finding with any other kind. The reminder counts a kind and subject across sessions, so keep the names fixed.

| Kind | What it is | Subject |
|---|---|---|
| `hook_block` | a hook denied, asked, or sent Claude back after a tool call | the hook script |
| `hook_stop_block` | a Stop hook sent Claude back at the end of a turn | the hook script |
| `guard_block` | a guard of Claude Code refused a call, such as the worktree guard | the first words of the guard text |
| `user_rejected` | the user rejected a tool call | the tool |
| `hook_failed` | a hook failed to run, such as a script that is gone | the hook script |
| `repeated_call` | the same tool call with the same input, with no change and no error between | the tool and its input |
| `reread` | a file read again with no edit of it between | the file |
| `undo_redo` | an edit that puts back the text of an earlier edit | the file |
| `circle` | the session went back to a step it had done, a loop the scan does not see | a short name of the step |
| `misunderstood_request` | Claude read the user's words in a way the user then corrected | a short name of the request |
| `wrong_approach` | Claude chose a way of working that the user then corrected | a short name of the approach |

The last two keep the friction names of `/insights`.

The scan also gives two kinds that are not findings: `user_turn`, a user message after a reply, and `interrupt`, a turn the user stopped. The model reads them and turns a correction into `misunderstood_request` or `wrong_approach`.
