```graph
begin start
end forked
fail fact_missing not_in_cmux command_failed
external fork_sh check_state check_output
start: The user runs one of the two fork skills. Its SKILL.md runs one script and reads nothing else.
start.run: op-skills:fork_sh
facts?: Could the script find the facts it needs from the environment and git?
cmux?: Does the session run inside cmux?
fork?: Did cmux open a pane and did claude start the fork in it?
forking: The script sends the cd and the fork command to a new pane, then the checks test the run.
forking.run: op-skills:fork_sh, check_state, check_output
forked: The fork runs in a new pane. The script prints one line.
forked.run: op-skills:fork_sh
fact_missing: A fact is missing. Nothing is opened and the script names the fact.
fact_missing.run: op-skills:fork_sh
not_in_cmux: The session is not in cmux. Nothing opens. The script prints the fork command.
not_in_cmux.run: op-skills:fork_sh
command_failed: A cmux or claude call failed. The script closes its pane, removes the new worktree.
command_failed.run: op-skills:fork_sh
fork_sh: The script op-fork-keep/scripts/fork.sh, which both fork skills run
check_state: The state check of the fork skills, which reports the state the run ended in
check_output: The output check of the fork skills, which prints nothing on a pass
start -> facts?
facts? -> cmux? [yes], fact_missing [no]
cmux? -> forking [yes], not_in_cmux [no]
forking -> fork?
fork? -> forked [yes], command_failed [no]
```
