```graph
external project-map folder-status project-start nested-instructions add-dir-context folder-pane local-e2e code-worktrees point-at-folder
point-at-folder: components/point-at-folder/ Point at one folder: its siblings on the map, and its skills and CLAUDE.md files up to the git root.
local-e2e: components/local-e2e/ Three test folders next to the harness, and an e2e script of real sessions on them.
code-worktrees: components/code-worktrees/ project-start adds a worktree of each code repo in place of its main checkout.
project-map: components/project-map/ One page: each folder, its project and its KB.
folder-status: components/folder-status/ The status line names each folder the session works on, and its project.
project-start: components/project-start/ One command starts a session in the harness with each folder of a project added.
nested-instructions: components/nested-instructions/ A file read or edit in an added folder loads the instructions of its folder.
add-dir-context: components/add-dir-context/ On /add-dir, Claude gets the project, role and KB of the folder.
folder-pane: components/folder-pane/ A domains button opens a pane: the selected domain, its folders, and each domain to pick.
project-map -> folder-status [project names]
project-map -> project-start [folders of a project]
folder-status -> folder-pane [the same folders, in a pane]
project-start -> add-dir-context [added folders]
add-dir-context -> nested-instructions [added folders]
add-dir-context -> folder-pane [roles and KBs]
code-worktrees -> project-start [worktree folders to add]
local-e2e -> project-start [real sessions on the test folders]
point-at-folder -> project-start [the project of a folder]
point-at-folder -> nested-instructions [skills and siblings in a session]
```
