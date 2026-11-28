# Folder status

## Goal

A line under the status line names each code folder the session works on, with its role from the map, so the user knows which folder to open in VS Code. The user sees at a glance what the session touches.

Route: poc

Builds: `scripts/statusline.sh` (the whole status line, linked from `~/.claude/statusline.sh`), `scripts/statusline-folders.sh` (one status line part from the status line input), `tests/global/folder-status/`, `scripts/project-map.py` (the `role` look-up and the role list), and its lines in `mac-setup/claude-code-setup.md`
Uses: the status line input `workspace.added_dirs`, `scripts/project-map.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, from the parent level `plans/global/components/multi-folder/`.

- **F6.** The script writes the domain of the session to the session file `domain`, and prints it as the first line of the status line: the largest domains of the map whose folders are all added, joined by `, `, or `no domain`. *(the user, 2026-11-24: "after selected still not updated, i think just call this domain, and on the status line actually show either no domain or the name of the domain")*
- **F7.** The whole status line lives in the harness as `scripts/statusline.sh`, with a test, and goes out with the public release. `~/.claude/statusline.sh` is a link to it in the main checkout. *(the user, 2026-11-28: "I want to release my current status line safely")*
- **F8.** The status line shows no branch: the folder with a red `wt-` in a worktree, the model, the context use, then the domain last. *(the user, 2026-11-28: "now that domain is in, the branch that is in, is not that helpful")*
- **F4.** The script writes the added folders of the session to a session file, so the add-dir context, the nested-instructions hook and the folder pane know them, also the folders of `--add-dir` at launch. *(the user, 2026-11-20)*

## Open questions

TBD

## Research questions

### User

TBD

### Claude

TBD
