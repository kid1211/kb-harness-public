```graph
begin input
end quiet shown
external status_line project_map
input: The status line gives its JSON on stdin, with workspace.added_dirs.
input.run: status_line
added?: Does the session have an added folder?
quiet: The script prints nothing, so the status line looks as before. The session file is empty.
group: The script asks the map for the project of each added folder, and groups them.
group.run: project_map
shown: The script prints each project once with its folders, the other folders by name, and saves them.
status_line: The script ~/.claude/statusline.sh, which adds the part to its line
project_map: scripts/project-map.py, the look-up of the project map
input -> added?
added? -> group [yes], quiet [no]
group -> shown
```
