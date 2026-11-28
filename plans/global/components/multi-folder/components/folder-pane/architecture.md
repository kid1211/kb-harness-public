```graph
begin closed
end shown picked
external user folder-context mod
closed: The writing-mode line shows the domains button, and the pane is not open.
closed.run: mod
pressed: The user presses the domains button.
pressed.run: user
open?: Is the pane open?
loading: The mod opens the pane, and reads the session files and the map.
loading.run: folder-context
shown: The pane shows the selected domain, the added folders, and each domain to pick.
shown.run: mod
picked: A click on a domain prints its /add-dir lines in the chat, with no model call.
picked.run: mod
folder-context: scripts/folder-context.py --json for the roles, and project-map.py domains for the map
user: The user, who reads the pane
mod: .claude/skills/folder-pane/ draws the pane. writing-mode draws its button
closed -> pressed
pressed -> open?
open? -> closed [yes: close it], loading [no]
loading -> shown [the mod has the data]
shown -> shown [Refresh reads the data again], picked [a click on a domain]
picked -> picked [a click on one more domain]
```
