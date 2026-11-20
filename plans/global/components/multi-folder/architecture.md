```graph
external project-map folder-status project-start nested-instructions add-dir-context folder-pane
project-map: components/project-map/ One page: each folder, its project and its KB.
folder-status: components/folder-status/ The status line names each folder the session works on, and its project.
project-start: components/project-start/ One command starts a session in the harness with each folder of a project added.
nested-instructions: components/nested-instructions/ A file read or edit in an added folder loads the instructions of its folder.
add-dir-context: components/add-dir-context/ On /add-dir, Claude gets the project, role and KB of the folder.
folder-pane: components/folder-pane/ A button opens a side pane of the folders by role, and the KB of each project.
project-map -> folder-status [project names]
project-map -> project-start [folders of a project]
folder-status -> folder-pane [the same folders, in a pane]
project-start -> add-dir-context [added folders]
add-dir-context -> nested-instructions [added folders]
add-dir-context -> folder-pane [roles and KBs]
```
