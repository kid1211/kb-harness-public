```graph
begin called
end silent given noted
external claude
hook nested-instructions
called: Claude Code ran the hook, after a Read, Edit or Write, or after it loaded a CLAUDE.md.
called.run: claude
event?: Which event runs the hook?
noted: The hook notes the CLAUDE.md that Claude Code loaded, so it never gives it.
noted.run: nested-instructions
outside?: Is the file outside the start folder of the session?
walk: The hook lists each CLAUDE.md above the file, and the root one if the repo was not added.
walk.run: nested-instructions
new?: Is one of them neither given nor loaded in this session?
silent: The hook prints nothing, and the call goes on.
given: The hook gives Claude the text of each new CLAUDE.md, and marks it given.
given.run: nested-instructions
claude: Claude Code, which runs the hook after a Read, Edit or Write, and on InstructionsLoaded
nested-instructions: .claude/hooks/nested-instructions.sh
called -> event?
event? -> noted [InstructionsLoaded], outside? [tool call]
outside? -> walk [yes], silent [no]
walk -> new?
new? -> given [yes], silent [no]
```
