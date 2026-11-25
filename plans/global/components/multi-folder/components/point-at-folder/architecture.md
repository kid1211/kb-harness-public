```graph
begin asked
end started
fail unmapped
external user project_start project_map claude
asked: The user runs project-start.sh --from with one folder.
asked.run: user
mapped?: Is the folder on a row of the project map?
started: claude starts with each sibling of the project and the git root of the folder added.
started.run: project_start
unmapped: Nothing starts. The script asks the user to add a row for the folder.
unmapped.run: project_start
user: the user, at a terminal
project_start: scripts/project-start.sh --from
project_map: scripts/project-map.py
claude: The claude CLI, with --add-dir
asked -> mapped?
mapped? -> started [yes], unmapped [no]
project_start -> project_map
```
