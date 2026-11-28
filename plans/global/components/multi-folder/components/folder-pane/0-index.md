# Folder pane

## Goal

A mod button, like the config button of writing-mode, opens a pane on the side. It shows the selected domain and the added folders with their roles, then each domain of the map to pick, and at the bottom the loaded instructions.

Route: poc

Builds: `.claude/skills/folder-pane/`
Uses: the mod API of Claude Code, `scripts/project-map.py` (the `domains` look-up, with each domain prompt), `git worktree list`, VS Code, `scripts/project-start.sh`, the writing-mode mod as the example of a button and a pane

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-20.

- **F1.** A button in the writing-mode line, next to `⚙ config`, opens and closes the pane, titled Domains. Its label is `⧉ domain`. `/domains` opens it too. *(the user, 2026-11-24: "let's change folders to domains", "after selected still not updated, i think just call this domain, and on the status line actually show either no domain or the name of the domain")*
- **F12.** The top part, Active domain, names the domain the session works on and lists each added folder after a tag of its role, in the colour of the role. The selected domain is the largest domain of the map whose folders are all added. *(the user, 2026-11-24: "on the top show what is selected and what are the folders added", of the role tags: "those should be inside of domain")*
- **F13.** Under a "Pick one from this list" heading, the pane lists each domain of the map, numbered. A click on one closes the pane, with no model call. With no active domain, the click runs `/add-dir <folder>` for each of its folders not added yet. A line that cannot run goes to the chat and to the clipboard, ready to paste. *(the user, 2026-11-24: "if i click any one of them, output me on the normal pane of what add-dir to do", "when it is selected the pane should be closed", "the goal is to have multiple that we need to add", "make the text copy and paste ready", "it should add multiple no?")*
- **F14.** With another domain active, the chat and the clipboard get only the command that starts a fresh session with the clicked domain: `bash ~/second-brain/harness/scripts/project-start.sh <domain>`. Claude Code cannot remove an added folder. A folder on no row of the map, such as `personal`, makes no domain active. *(the user, 2026-11-24: "if we are switching we need to also remove dir?", "if no domain, then just give me list of add-dir", "if domain selected, give me" the project-start line)*
- **F15.** Active domain and "Pick one from this list" are headings, in the heading colour, and their items have no indent. The selected domain name is in its own colour, the one the status line gives it. *(the user, 2026-11-24: "selected and select can be heading no?", "the name should be in different color")*
- **F16.** Each added folder shows as its last three folder names, such as `test-folders/folder-a/web`. *(the user, 2026-11-24: "the path just give me the 3 level deep from the actual folder")*
- **F20.** A domain with a `### <domain>` heading under `## Domain prompts` of the map has a prompt. After its `/add-dir` lines run, a pick puts that prompt in the prompt box, so the user types the task at its end. A switch to a new session gets no prompt.
- **F17.** A worktrees button sits next to the domains button and opens and closes a pane, titled Worktrees. `/worktrees` opens it too. *(the user, 2026-11-28: "Next to domains, have a button called show current working tree")*
- **F18.** The Worktrees pane lists only the repos of the selected domain, once per repo: its main checkout with its branch, then each worktree made from it with its branch. A folder out of git says so. With no domain selected, it says so. Under "This session" it shows the worktree this session runs in, or its main checkout. No other worktree of the start folder shows. *(the user, 2026-11-28: "show any of the worktree and folder", then "i only want the current active domain that have worktree associated with this, not all worktrees", "only show the domain selected (or worktree that is updated in the current session")*
- **F19.** Only a made worktree is a button. A press opens that whole folder in VS Code, where its Source Control view shows the diff. The main checkout is no button. *(the user, 2026-11-28: "only worktree folders that is created can be clickable and when click open that entire folder in vscode (I want to see the git diff)")*
- **F5.** The pane updates when the user adds a folder. *(the user, 2026-11-20)*
- **F6.** The pane lists the instructions files the session has for each folder, so the user sees what Claude loaded. *(the user, 2026-11-20)*
- **F7.** The instructions part shows one text warning to the user: Claude Code 2.1.329 does not load the instructions of a subfolder in an added folder, so check this again after an update. *(the user, 2026-11-20)*
- **F8.** Each folder and file path in the pane is a link: a click opens it. *(the user, 2026-11-20)*
- **F9.** The instructions part, with its warning, is hidden by default. A button shows and hides it. *(the user, 2026-11-20)*
- **F11.** The instructions part lists each folder that holds a loaded instructions file, by its full path, once, with a short tag of how it loaded. The warning sits at the bottom of the pane. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
