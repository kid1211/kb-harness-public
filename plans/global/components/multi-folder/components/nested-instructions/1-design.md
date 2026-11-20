# Nested instructions: design

## State transitions

Model: [nested-instructions.qnt](nested-instructions.qnt).

```graph
import-graph: architecture.md
```

1. [called](#called): Claude ran Read, Edit or Write on a file, or Claude Code loaded a `CLAUDE.md`.
2. [noted](#noted): the event is `InstructionsLoaded`.
3. [walk](#walk): the file is outside the start folder, and the hook looks for each `CLAUDE.md` above it.
4. [silent](#silent): the file is in the start folder, or each `CLAUDE.md` it wants was given or loaded before.
5. [given](#given): the hook printed the text of each new `CLAUDE.md`, and recorded it for the session.

## State deep dive

### called

The hook reads `hook_event_name`, `session_id`, `cwd` and, for a tool call, `tool_input.file_path` from its JSON input on stdin. The session folder is `${CLAUDE_MULTI_FOLDER_STATE:-~/.claude/multi-folder}/<session_id>/`. Its `instructions` file holds one line per `CLAUDE.md` of the session: the path, a tab, and who loaded it.

**Invariants:** `insideSilent`.

**Expected output:** none yet.

### noted

The `InstructionsLoaded` input has `file_path` and `load_reason`. The hook adds the line `<path>\t<load_reason>` to `instructions`.

**Invariants:** `neverLoaded`.

**Expected output:** nothing. Exit 0.

### walk

- The hook goes up from the folder of the file, to the top of its git repo. With no repo, it stops at `$HOME`.
- It keeps each `CLAUDE.md` it finds below the top, the highest one first. It leaves out a folder above the start folder, since Claude Code loads those.
- It adds the `CLAUDE.md` of the top itself, unless the top is the start folder or a line of the session's `dirs` file. An added folder loads its own top file.
- A file in the start folder, by its own path or by a symlink, gets nothing.

**Invariants:** `givenAbove`.

**Expected output:** the paths of the `CLAUDE.md` files the file wants.

### silent

**Invariants:** `insideSilent`, `onlyNew`.

**Expected output:** nothing on stdout. Exit 0.

### given

The hook prints one JSON object: `hookSpecificOutput` with `hookEventName: "PostToolUse"` and `additionalContext`. The context holds, for each new file, a line `Instructions from <path>:` and its text. A file already in `instructions` is not new. Once the JSON is out, the hook adds `<path>\thook` for each one.

**Invariants:** `onlyNew`, `givenAbove`, `neverLoaded`.

**Expected output:** the JSON on stdout, and the lines in `instructions`. Exit 0.

## Build checks

Unit tests: `tests/global/nested-instructions/test-nested-instructions.sh`, with a throwaway git repo, a throwaway start folder and a throwaway `CLAUDE_MULTI_FOLDER_STATE`.

| Check | Holds |
|---|---|
| a file deep in an added repo gives both `CLAUDE.md` files below its top | `walk`, `give`, `givenAbove`, `deepTest` |
| a second file of the same repo gives nothing new | `nothingNew`, `onlyNew`, `onceTest` |
| a file in the start folder, or reached by a symlink from it, gives nothing | `inside`, `insideSilent`, `insideTest` |
| a file in a repo not added gives the top `CLAUDE.md` too | `give`, `givenAbove`, `notAddedTest` |
| a `CLAUDE.md` that `InstructionsLoaded` noted is not given | `note`, `neverLoaded`, `loadedTest` |
| a `CLAUDE.md` above the start folder is left out | expected output of `walk` |
| with no repo, the walk stops below `$HOME` | expected output of `walk` |
| bad input, or no file path, exits 0 with no output | F4 |
| the settings run the hook after Read, Edit and Write, and on `InstructionsLoaded` | wiring |

No check sees that Claude reads the context and keeps to it. A fresh `claude -p` shows the context arrives.

## Coverage

| Want | Held by |
|---|---|
| F1 | `walk`, `give`, `givenAbove`, `deepTest` |
| F2 | `nothingNew`, `onlyNew`, `onceTest` |
| F3 | `inside`, `insideSilent`, `insideTest` |
| F4 | not in the model: an exit code is code, not a state. The bad-input test holds it |
| F5 | `give`, `givenAbove`, `notAddedTest` |
| F6 | `note`, `neverLoaded`, `loadedTest` |
| called | `initWith` starts a call with what the session got before |
| noted | `loadedTest` |
| silent | `onceTest`, `insideTest` |
| given | `deepTest`, `notAddedTest` |
| start and end | `goOn` starts the next call from noted, silent or given |
| negative control | `neverGives`: the checker finds a call that gives a `CLAUDE.md` |

## Risks

- A long `CLAUDE.md` fills the context. The hook gives each file once per session only.
- A `/compact` drops what the hook gave, and the session file still marks it given. Then Claude lacks it until a new session.
- If a Claude Code update loads the nested files of an added folder, `InstructionsLoaded` notes them first, and the hook stays quiet. The folder pane warns the user to check this after each update.
- The `dirs` file comes from the status line and from `/add-dir`. A repo added at launch before the status line ran counts as not added once, and its top file comes once.

## Appendix

- The research of the parent level, Q3: `personal/claude-research/staging/2026-11-19-multi-folder/multi-folder.staging.md`. A nested `CLAUDE.md` of an added folder did not load in the test.
- The hook input and output fields: the Claude Code hooks docs, `PostToolUse` and `additionalContext`, and the `InstructionsLoadedHookInput` of the mod API of Claude Code 2.1.329.
