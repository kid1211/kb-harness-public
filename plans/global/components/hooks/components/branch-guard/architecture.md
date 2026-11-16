```graph
begin received
end allowed refused
fail failed_open
external pre_tool_use
received.run: branch-guard:branch-guard.sh
parsed.run: branch-guard:branch-guard.sh
located.run: branch-guard:branch-guard.sh
pre_tool_use: Claude Code, before each Bash call of Claude or of a subagent.
received: The hook has the text of one Bash call on stdin, as JSON with the command and the cwd
names_git?: Does the text hold the word git?
input_ok?: Can the hook read the command and the cwd, and split the command into parts?
has_git_part?: Does the command hold a git part, also inside bash -c or sh -c, one level deep?
parsed: The hook has split the command into its git parts, and takes the next one
switch?: Does the part run git switch?
new_in_main?: Does the git switch have -c, -C or --orphan
form?: Which form is the part?
located: The hook has found the repo of the part, from -C, cd, --git-dir, GIT_DIR or else the cwd.
git_ok?: Did each git call of the hook work?
harness_main?: Is the repo the main checkout of the harness?
remote_only?: Can the hook read the name, and does a remote-tracking ref have it, with no local branch?
more?: Is another git part left?
allowed: The hook exits 0, and the command runs. A part whose git call failed left a warning on stderr
refused: The hook exits 2, and the command does not run.
failed_open: The hook cannot read its input, cannot split the command, or fails itself.
pre_tool_use -> received
received -> names_git?
names_git? -> allowed [no: exit at once], input_ok? [yes]
input_ok? -> failed_open [no], has_git_part? [yes]
has_git_part? -> allowed [no], parsed [yes]
parsed -> switch? [the next part]
parsed -> failed_open [the hook fails itself]
switch? -> new_in_main? [yes, in each repo], form? [no]
new_in_main? -> refused [yes: the message names EnterWorktree]
new_in_main? -> refused [no: the message names git checkout]
form? -> located [a branch form, or git checkout with a name], more? [git worktree add, or another form]
located -> git_ok? [the calls are done]
located -> failed_open [the hook fails itself]
git_ok? -> more? [no: the part passes, with a warning], harness_main? [yes]
harness_main? -> more? [no: another repo, or a linked worktree], refused [yes, a branch form], remote_only? [yes, git checkout with a name]
remote_only? -> refused [yes], more? [no]
more? -> parsed [yes], allowed [no]
```
