```graph
begin start
end switched empty_removed remote_removed force_removed discarded
fail blocked_dirty
skill wt_end_sh
start: The user picks how the worktree ends
start.run: worktree-end:SKILL.md, wt_end_sh
blocked_dirty: Uncommitted changes stop the run
switch_confirm: The user confirms leaving, or goes back
switch_confirm.run: worktree-end:SKILL.md
switched: The worktree is kept with its commits
discard_confirm: The user types delete, or goes back
discard_confirm.run: worktree-end:SKILL.md
discard_kept: Discard confirmed, remove refused
discard_kept.run: wt_end_sh
discarded: The worktree and its commits are removed
empty_kept: No commits, remove refused
empty_kept.run: wt_end_sh
empty_removed: No commits, the worktree is removed
merge_now_check: Push and merge the PR in one run
merge_now_check.run: wt_end_sh
merge_blocked: GitHub refused, the user stays in the worktree
merge_blocked.run: worktree-end:SKILL.md
remote_check: Check the pushed branch against its PR
remote_check.run: wt_end_sh
remote_waiting: PR open, the worktree is kept
remote_waiting.run: wt_end_sh
remote_kept: PR merged, remove refused
remote_kept.run: wt_end_sh
remote_removed: PR merged, the worktree is removed
force_removed: Removed by hand after a typed delete
wt_end_sh: The script that runs each git and gh step
start -> blocked_dirty [dirty], switch_confirm [leave], discard_confirm [discard], empty_kept [empty, refused], empty_removed [empty], merge_now_check [merge now], remote_check [merge]
switch_confirm -> switched [yes], start [no]
discard_confirm -> discarded [delete], discard_kept [delete, refused], start [no]
discard_kept -> force_removed [delete]
empty_kept -> force_removed [delete]
merge_now_check -> remote_check [merged], merge_blocked [refused]
merge_blocked -> start [fixed]
remote_check -> remote_removed [merged], remote_kept [merged, refused], remote_waiting [open]
remote_kept -> force_removed [delete]
remote_waiting -> remote_check [again]
```
