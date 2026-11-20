# Multi-folder sessions

## Goal

One session works on several folders at once: code repos, such as a frontend and a backend, as well as KBs.

- A map says which folder is which project and which KB goes with it.
- Each folder's own skills and instructions load when the session works in it.
- The session always shows which folders and project it works on.

The route, from the research answer to the first the user question below:

- Each session starts in the harness, so the harness hooks run.
- The code folders come in with `/add-dir`, so each one's own skills load.
- No harness link goes into a code repo.

Builds: nothing of its own. Each component names the paths it builds.
Uses: Claude Code `--add-dir` and `/add-dir`, the status line input `workspace.added_dirs`, the `personal` KB
Route: split

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

The user's wants, 2026-11-19: "some times i need you to work on actual folders to work on code", "work on multiple fodler ... some front end some backend", "in the reference give idea of the different relationship like fodler kb 1 is for project 1 ... and have this mappign for easy query", "load the skill/read the skill in the individual fodler depend on what we want to operate", "but more importantly how can we know we are operating x thigns", and "maybe we should go back to the old route of symlinking harness skill where ever i go".

- **F1.** A session works on code folders, not only KBs, and on more than one folder at once. *(the user, 2026-11-19)*
- **F2.** A map says which folder is which project, and which KB goes with it, for a fast look-up. *(the user, 2026-11-19)*
- **F3.** The skills and instructions of each folder load when the session works on it. *(the user, 2026-11-19)*
- **F4.** The session always shows which folders and which project it works on. This want comes first. *(the user, 2026-11-19)*
- **F5.** Pick the best route between a mod, `/add-dir`, and links to the harness skills in each folder, from research. *(the user, 2026-11-19)*

## Open questions

TBD

## Research questions

### User

1. answered [Which route lets one session work on code folders with the harness skills and each folder's own skills?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q7-which-route-lets-one-session-work-on-code-folders-with-the-harness-skills-and-each-folders-own-skills)
2. answered [Where does the session show which folders and project it works on?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q8-where-does-the-session-show-which-folders-and-project-it-works-on)

### Claude

1. answered [Does a folder added with `--add-dir` give the session its own skills?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q1-does-a-folder-added-with---add-dir-give-the-session-its-own-skills)
2. answered [Does a folder added with `--add-dir` give the session its own `CLAUDE.md`?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q2-does-a-folder-added-with---add-dir-give-the-session-its-own-claudemd)
3. answered [Does a `CLAUDE.md` in a subfolder of an added folder load when Claude reads a file there?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q3-does-a-claudemd-in-a-subfolder-of-an-added-folder-load-when-claude-reads-a-file-there)
4. answered [Do the hooks and settings of an added folder load?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q4-do-the-hooks-and-settings-of-an-added-folder-load)
5. answered [Does `permissions.additionalDirectories` in settings load the folder's skills and instructions?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q5-does-permissionsadditionaldirectories-in-settings-load-the-folders-skills-and-instructions)
6. answered [Can the status line see which folders a session added?](../../../../../personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md#q6-can-the-status-line-see-which-folders-a-session-added)
