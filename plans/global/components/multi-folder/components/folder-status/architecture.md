```graph
begin input
end quiet shown
external status_line project_map
input: The status line gives its JSON on stdin, with workspace.added_dirs.
input.run: status_line
added?: Does the session have an added folder?
quiet: The script prints no domain. The session file is empty.
group: The script finds the checkout of each added folder, and asks the map for its role.
group.run: project_map
shown: The script prints each code folder by role and name, and saves the added folders.
status_line: The script ~/.claude/statusline.sh, which adds the part to its line
project_map: scripts/project-map.py, the look-up of the project map
input -> added?
added? -> group [yes], quiet [no]
group -> shown
```
