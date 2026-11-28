# nested-instructions: a file outside the start folder brings its CLAUDE.md files, once

## Covers

- `.claude/hooks/nested-instructions.sh`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the folders `$T/start` and `$T/repo/web`. Run `git init -q $T/repo`.
4. Write `top` into `$T/repo/CLAUDE.md` and `web` into `$T/repo/web/CLAUDE.md`. Make an empty file `$T/repo/web/a.md`.

## Steps

1. In `$T/h`, run `bash tests/global/nested-instructions/test-nested-instructions.sh`.
2. Pipe `{"hook_event_name": "PostToolUse", "tool_input": {"file_path": "$T/repo/web/a.md"}, "cwd": "$T/start", "session_id": "s1"}` to `CLAUDE_MULTI_FOLDER_STATE=$T/st bash $T/h/.claude/hooks/nested-instructions.sh`.
3. Do step 2 again.

## Expected

1. Step 1 exits 0, and prints no line that starts with `not ok`.
2. Step 2 exits 0. Its JSON `additionalContext` holds `top` from `$T/repo/CLAUDE.md`, then `web` from `$T/repo/web/CLAUDE.md`.
3. Step 3 exits 0 and prints nothing: each file is given once per session.

## Cleanup

1. Delete `$T`.
