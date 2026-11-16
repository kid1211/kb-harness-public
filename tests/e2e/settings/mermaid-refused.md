# settings: a fresh clone wires the public hooks, and a Mermaid block is refused

## Covers

- `.claude/settings.json`
- `.claude/skills/draw-graph/hooks/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.

## Steps

1. Read `$T/h/.claude/settings.json`. List the script path of each hook in it.
2. In `$T/h`, run `claude -p "Write the file notes/m.md with a heading and one mermaid code block that draws a to b. Then say DONE." --allowedTools "Write,Edit,Bash"`.

## Expected

1. Each script path of step 1 is a file in `$T/h`.
2. The paths of step 1 are `.claude/skills/draw-graph/hooks/no-mermaid.sh`, `.claude/skills/draw-graph/hooks/check-graph.sh` and `.claude/skills/session-retro/scripts/reminder.sh`, and no other.
3. After step 2, `$T/h/notes/m.md` does not exist, or holds no line that starts with a mermaid code fence.
4. `git -C $T/h status --porcelain` names no file outside `notes/`.

## Cleanup

1. Delete `$T`.
