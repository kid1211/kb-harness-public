```graph
begin closed
end shown
external user folder-context mod
closed: The writing-mode line shows the folders button, and the pane is not open.
closed.run: mod
pressed: The user presses the folders button.
pressed.run: user
open?: Is the pane open?
loading: The mod opens the pane, and reads the session files and the map.
loading.run: folder-context
shown: The pane shows the coding folders and the KBs as links, and a button for the instructions.
shown.run: mod
user: The user, at the prompt
folder-context: scripts/folder-context.py --json, the project, role and docs of each folder
mod: .claude/skills/folder-pane/ draws the pane. writing-mode draws its button
closed -> pressed
pressed -> open?
open? -> closed [yes: close it], loading [no]
loading -> shown
```
