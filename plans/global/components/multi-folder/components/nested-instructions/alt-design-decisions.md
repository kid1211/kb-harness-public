# Nested instructions: designs not chosen

- **A `PreToolUse` script.** Not chosen: Claude then gets the text before it sees the page it asked for. After the call, the text comes with the page, and the call goes on.
- **Give each `CLAUDE.md` on each call.** Not chosen: the same text would fill the context again and again.
- **A `DirectoryAdded` script that loads the whole folder.** Not chosen: it would load each nested `CLAUDE.md` of a big repo. That includes those of folders Claude never opens.
