```graph
begin asked
end started
external project_map claude user script git
asked: The user runs project-start.sh with a project name and --worktree and a name.
asked.run: user
made: Each code repo has its worktree of that name, made or reused, and excluded from its git status.
made.run: git
started: claude starts with each worktree, KB and plain folder added. The script prints them.
started.run: claude
user: The user, at a terminal
script: scripts/project-start.sh
git: git worktree add, and .git/info/exclude of the repo
project_map: scripts/project-map.py, the look-up of the project map
claude: The claude CLI, with --add-dir
asked -> made
made -> started
script -> project_map
```
