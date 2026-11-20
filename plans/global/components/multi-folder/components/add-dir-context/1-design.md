# Add-dir context: design

## State transitions

Model: [add-dir-context.qnt](add-dir-context.qnt).

```graph
import-graph: architecture.md
```

1. [called](#called): Claude Code ran the hook, on `DirectoryAdded` or on `UserPromptSubmit`.
2. [recorded](#recorded): The user ran `/add-dir`, and the hook saved the folder.
3. [told](#told): a prompt came, and the session file holds a folder Claude was not told about.
4. [silent](#silent): a prompt came, and Claude knows each saved folder.

## State deep dive

### called

One script serves both events. It reads `hook_event_name` and `session_id` from its JSON input. The session folder is `${CLAUDE_MULTI_FOLDER_STATE:-~/.claude/multi-folder}/<session_id>/`. The status line writes its `dirs` file with each added folder, also those of `--add-dir` at launch.

**Invariants:** `toldSaved`.

**Expected output:** none yet.

### recorded

The `DirectoryAdded` input has `directory`. The hook adds it to `dirs`, once. Claude Code drops the output of this event, so the hook prints nothing.

**Invariants:** `recordQuiet`.

**Expected output:** nothing. Exit 0.

### told

For each folder in `dirs` and not in `told`, the hook runs `scripts/folder-context.py <folder>...`. That script reads the map with all its columns:

- A folder on a row: `Folder <path>: project <project>, role <role>.`, then `Supporting docs of <project>: <folder> (<role>), ...`. The docs are the rows of the project that the KB column names, less the folder itself.
- A folder on no row: `Folder <path>: on no row of the project map.`
- `--json` prints the same as a JSON array, for the folder pane.

The hook prints `hookSpecificOutput` with `hookEventName: "UserPromptSubmit"` and `additionalContext`: the line `Folders added to this session, from the project map:`, then the lines of the script. It then adds the folders to `told`.

**Invariants:** `toldFromDirs`, `toldSaved`.

**Expected output:** the JSON on stdout. Exit 0.

### silent

**Invariants:** `toldSaved`.

**Expected output:** nothing. Exit 0.

## Build checks

Unit tests: `tests/global/add-dir-context/test-add-dir-context.sh`, with a throwaway map in `PROJECT_MAP` and a throwaway `CLAUDE_MULTI_FOLDER_STATE`.

| Check | Holds |
|---|---|
| a `DirectoryAdded` input saves the folder and prints nothing | `record`, `recordQuiet`, `addTest` |
| a prompt after an add gives the project, role and supporting docs | `tell`, `toldFromDirs`, `tellTest` |
| a second prompt gives nothing, and the told file holds only saved folders | `quiet`, `toldSaved`, `onceTest` |
| a folder on no row gets the no-row line | expected output of `told` |
| `--json` gives the same facts as JSON | expected output of `told` |
| bad input exits 0 with no output | F4 |
| the settings run the hook on `DirectoryAdded` and `UserPromptSubmit` | wiring |

No check sees that Claude reads the context. A live `/add-dir` and a question show it.

## Coverage

| Want | Held by |
|---|---|
| F1 | `tell`, `toldFromDirs`, `tellTest` |
| F2 | `quiet`, `toldSaved`, `onceTest` |
| F3 | the hook gives no instructions file text. The nested-instructions hook gives it |
| F4 | not in the model: an exit code is code. The bad-input test holds it |
| F5 | `record`, `recordQuiet`, `addTest` |
| called | `initWith` starts a call with the saved files |
| recorded | `addTest` |
| told | `tellTest` |
| silent | `onceTest` |
| start and end | `goOn` starts the next call |
| negative control | `neverTells`: the checker finds a prompt that tells Claude |

## Risks

- The context comes with the user's next prompt, not at the `/add-dir` itself. Claude Code drops the output of `DirectoryAdded`.
- A folder of `--add-dir` at launch reaches `dirs` only once the status line ran. It runs before the first prompt, so the first prompt carries it.
- The hook runs on each prompt. With nothing new it reads two small files and exits.

## Appendix

- The spike of 2026-11-20: an `expect` run of a live session with a `DirectoryAdded` hook. The hook got `directory` and `source: "slash_command"`. Its `additionalContext` and `systemMessage` reached neither Claude nor the screen. `--add-dir` at launch did not run the hook.
- The hook input types: the `DirectoryAddedHookInput` of the mod API of Claude Code 2.1.329.
