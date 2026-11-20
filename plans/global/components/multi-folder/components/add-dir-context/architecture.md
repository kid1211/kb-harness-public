```graph
begin called
end recorded told silent
external claude
hook add-dir-context folder-context
called: Claude Code runs the hook: on /add-dir, or on each prompt of the user.
called.run: claude
event?: Which event runs the hook?
recorded: The hook adds the new folder to the session file, and prints nothing.
recorded.run: add-dir-context
new?: Is a folder of the session file not yet told to Claude?
told: The hook gives Claude the project, role and supporting docs of each new folder, and marks it told.
told.run: folder-context
silent: The hook prints nothing, and the prompt goes on.
claude: Claude Code, which runs the hook on DirectoryAdded and UserPromptSubmit
add-dir-context: .claude/hooks/add-dir-context.sh
folder-context: scripts/folder-context.py, the context of a folder from the project map
called -> event?
event? -> recorded [DirectoryAdded], new? [prompt]
new? -> told [yes], silent [no]
```
