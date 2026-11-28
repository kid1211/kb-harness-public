# project-map: a KB split into domains gives each domain with its prompt, and its commit check passes

## Covers

- `scripts/project-map.py`
- `.claude/hooks/project-map-check.sh`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the git repo `$T/kb` with the folders `$T/kb/trade` and `$T/kb/health`, and the git repo `$T/lone`.
4. Write `$T/map.md`, `$T` written out in full:

   | Project | Folder | Role | KB | Note |
   |---|---|---|---|---|
   | trade | $T/kb/trade | KB | kb | the trade domain |
   | health | $T/kb/health | KB | kb | the health domain |

   Under it, write `## Domain prompts`, then `### trade` with the line `Check the trade notes.`

## Steps

1. In `$T/h`, run `bash tests/global/project-map/test-split-kb.sh`.
2. Run `PROJECT_MAP=$T/map.md python3 -I $T/h/scripts/project-map.py domains`.
3. Run `jq -n --arg d $T/kb '{tool_input: {command: "git commit -m x"}, cwd: $d}' | PROJECT_MAP=$T/map.md bash $T/h/.claude/hooks/project-map-check.sh`.
4. Run step 3 with `$T/lone` in place of `$T/kb`.

## Expected

1. Step 1 exits 0, and prints no line that starts with `not ok`.
2. Step 2 prints JSON with the domains `trade` and `health`, in that order, each with its folder and the role `KB`. Only `trade` has a `prompt`, and it is `Check the trade notes.`
3. Step 3 prints nothing: the repo holds rows, so it needs no row of its own.
4. Step 4 prints JSON whose `additionalContext` asks the user for a row.

## Cleanup

1. Delete `$T`.
