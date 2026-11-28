# Writing mode: detailed requirements

## Requirements

These were built as part of the `writing-check` level, and moved here on 2026-10-28. Their source is R9 and R11 of `../../../hooks/components/writing-check/`.

- ✅ **R1. Mode buttons:** [implement] two buttons above the prompt set the mode of replies and of docs, each one of `off`, `casual` or `pro`. A press moves to the next mode, and the mod writes it to `~/.claude/writing-check-mode.json`. *(the user, 2026-10-23)*
  - Serves: F1
- ✅ **R2. The casual prompt section:** [implement] in `casual` mode, the mod adds a section to the system prompt that tells Claude to write like an engineer talking to a friend. *(the user, 2026-10-23)*
  - Serves: F1
- 🚀 **R9. Top row among the harness mods:** [implement] while no survey shows, the `writing-mode` row, with `⚙ config` on it, is the top row of the band among the harness mods, by R9 of the `mod` level. A mod from outside the harness that loads first may draw above it. *(the user, 2026-10-28)*
  - Serves: F1
- 🚀 **R10. Pass the band on:** [implement] while no survey shows, the mod draws the tree that `next(e)` gives below its own row, so the row of each mod beneath it still shows. If `next(e)` gives no tree, the mod draws its own row alone, with no error and no blank row. While a survey shows, it draws nothing of its own and passes the band on. *(the user, 2026-10-28)*
  - Serves: F1
- 🚀 **R8. One mode per machine:** [implement] the modes in `~/.claude/writing-check-mode.json` hold for every session on the machine. Each session reads the file again before it draws the band or adds the casual section. If the file is missing or does not parse, or a mode is missing from it, that mode is `pro`. So the buttons, the casual section and the `writing-check` hook of each session use the same mode. *(the user, 2026-10-28)*
  - Serves: F1
- 🚀 **R12. The report pane:** [implement] a press of the dim `⚙ config` button at the right of the band opens a pane with what `writing-check.py report` prints, if it is closed, and closes it if it is open. `/writing-check` only opens it. The pane has a Refresh button. *(the user, 2026-10-28)*
  - Serves: F2
- 🚀 **R13. The folders button:** [implement] a dim `⧉ folders` button sits left of `⚙ config` in the writing-mode row. Both buttons run one logic: a press runs `/<command> toggle` of the mod that owns the pane, `/folders` or `/writing-check`, which opens the pane if it is closed and closes it if it is open. The folder-pane mod owns, draws and fills its pane. *(the user, 2026-11-20)*
  - Serves: F3
