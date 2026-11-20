# Folder pane

## Goal

A mod button, like the config button of writing-mode, opens a pane on the side. It shows each folder the session loads, by project and with its role, and at the bottom the supporting docs of each project from the map.

Route: poc

Builds: `.claude/skills/folder-pane/`
Uses: the mod API of Claude Code, `scripts/project-map.py`, the writing-mode mod as the example of a button and a pane

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-20.

- **F1.** A `⧉ folders` button in the writing-mode line, next to `⚙ config`, opens and closes a pane on the side. `/folders` opens it too. *(the user, 2026-11-20)*
- **F2.** The pane lists the coding folders: each added folder that is not a KB, with its project. It leaves out the start folder, since the session runs in it. *(the user, 2026-11-20)*
- **F3.** The pane lists the KBs: each added KB folder, and each KB folder that the map gives a project of the session. A KB of the map that is not added says so. *(the user, 2026-11-20)*
- **F4.** Supporting docs and KBs are one thing: the pane has one KB part, not two. *(the user, 2026-11-20)*
- **F5.** The pane updates when the user adds a folder. *(the user, 2026-11-20)*
- **F6.** The pane lists the instructions files the session has for each folder, so the user sees what Claude loaded. *(the user, 2026-11-20)*
- **F7.** The instructions part shows one text warning to the user: Claude Code 2.1.329 does not load the instructions of a subfolder in an added folder, so check this again after an update. *(the user, 2026-11-20)*
- **F8.** Each folder and file path in the pane is a link: a click opens it. *(the user, 2026-11-20)*
- **F9.** The instructions part, with its warning, is hidden by default. A button shows and hides it. *(the user, 2026-11-20)*
- **F10.** The pane shows each coding folder and KB relative to the start folder, so a line stays short. *(the user, 2026-11-20)*
- **F11.** The instructions part lists each folder that holds a loaded instructions file, by its full path, once, with a short tag of how it loaded. The warning sits at the bottom of the pane. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
