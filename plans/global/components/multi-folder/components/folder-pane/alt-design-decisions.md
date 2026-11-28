# Folder pane: designs not chosen

- **Put the button into the writing-mode row.** Not chosen: two mods would then share one file. A row of its own keeps each mod on its own.
- **Read the added folders from the status line input.** Not chosen: a mod gets no status line input. The `dirs` session file carries them.

- **One section per role, and a separate supporting docs part.** Replaced on 2026-11-20: the user wants two main parts, the coding folders and the KBs. Supporting docs are the KBs, and the start folder is not listed.
- **`vscode://file/<path>` links.** Not chosen: a `file:` link opens in any terminal and any app, with no editor named.
- **A line of its own above the prompt.** Replaced on 2026-11-20: the user wants the button next to `⚙ config`. Claude Code stacks one line per mod and no mod can join two, so writing-mode draws the button.
- **writing-mode opens the pane by `$.ui.open`.** Replaced on 2026-11-20: the pane was then writing-mode's, so a second press did not close it. The button now runs `/folders toggle`, and this mod owns the pane.
