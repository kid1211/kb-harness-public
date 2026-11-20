```graph
begin asked
end started
fail unknown
external project_map claude user script
asked: The user runs project-start.sh with a project name.
asked.run: user
looked: The script asks the map for the folders of the project.
looked.run: project_map
known?: Is the project on the map?
unknown: The script prints the projects on the map and starts nothing.
check: The script keeps each folder that exists, and names each one that does not.
check.run: script
user: The user, at a terminal
script: scripts/project-start.sh
started: The script starts claude in the harness, with each kept folder added.
started.run: claude
project_map: scripts/project-map.py, the look-up of the project map
claude: The claude CLI, with --add-dir
asked -> looked
looked -> known?
known? -> check [yes], unknown [no]
check -> started
```
