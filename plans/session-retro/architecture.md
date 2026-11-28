```graph
begin idle
end committed
fail failed
external worktree-end findings findings-page spec-metrics
skill start_sh retro_sh reminder
worktree-end: Closes a worktree, then asks: Run a session retro?
yes?: Did the user say yes?
start_sh: start.sh finds the transcript and starts retro.sh in the background
idle: No run. A session on main stays here.
idle.run: worktree-end
running: retro.sh waits for the transcript to settle
running.run: retro_sh
retro_sh: retro.sh holds the session lock and runs each step
fresh?: Is the last transcript entry an hour old or less?
cold: The run reads nothing and writes a one-line page that says why.
cold.run: retro_sh
forked: A fork of the session judges the candidates of the scan. It runs no tool
forked.run: retro_sh, findings
written: findings-page.py wrote the page and moved it into personal.
written.run: findings-page, spec-metrics
committed: The page is committed alone on main and pushed
failed: The run wrote why into the failure log.
reminder: The SessionStart hook shows failures, and each 7 days the open findings
findings: components/findings/ What the run looks for
findings-page: components/findings-page/ The page and its secret check
spec-metrics: components/spec-metrics/ Round and level numbers
idle -> worktree-end [ExitWorktree]
committed -> worktree-end [ExitWorktree again]
failed -> worktree-end [ExitWorktree again]
worktree-end -> yes?
yes? -> start_sh [yes], idle [no]
start_sh -> running
running -> fresh? [transcript settled], failed [lock or transcript error]
fresh? -> forked [yes], cold [no]
forked -> findings
forked -> written [findings returned], failed [fork failed]
cold -> written [page written], failed [write failed]
written -> findings-page
written -> committed [commit works], failed [secret, or git failed]
failed -> reminder
committed -> reminder
```
