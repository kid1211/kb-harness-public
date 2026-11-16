# Writing mode: design

## State transitions

The model is [writing-mode.qnt](writing-mode.qnt), module `writingMode`.

```graph
import-graph: architecture.md
```

1. [Start](#start): the mod gets a band draw, a press of a mode button or of `⚙ config`, a prompt compose, or the open of another pane.
2. [Read modes](#read_modes): it reads the mode file of the machine again.
3. [Pass on](#pass_on): a survey holds the band, so the mod gives it the tree of `next(e)` alone.
4. [Draw row](#draw_row): the mod draws its row on top, then the tree of `next(e)` under it.
5. [Cycle](#cycle): the pressed mode moves on, and the mod writes the file.
6. [Compose](#compose): in casual mode, the mod adds the casual section.
7. [Toggle pane](#toggle_pane): a press of `⚙ config` opens the pane if it is closed, and closes it if it is open.
8. [Close pane](#close_pane): another harness mod opens its pane, so the mod closes its own.

## State deep dive

### Start

Five events start here, in `.claude/skills/writing-mode/hooks/register.tsx`: `ui.render` on `{ component: 'AbovePrompt' }`, the `onPress` of each mode button, the `onPress` of `⚙ config`, `prompt.compose`, and the `ui.open` hook of another pane. The `session.start` hook registers the command only: each event reads the modes itself.

**Invariants:** none of its own.

**Expected output:** none. The event goes on to Read modes.

### Read modes

The model action is `readModes`.

A function `load($)` reads `~/.claude/writing-check-mode.json` with `$.fs.read`. For each kind, `reply` and `docs`, the mode is the value in the file if it is `off`, `casual` or `pro`. Else it is `pro`: a missing file, a file that does not parse, valid JSON that is not an object, a missing key, or another value.

The band draws from the value it read, not from an atom. A draw writes no state, so it cannot start a redraw of its own. A press writes the file, then the `modes` atom, and that write redraws the band once.

Each session reads the file at each event, so a press in one session shows in the others at their next draw, and the `writing-check` hook reads the same file.

**Invariants:** `modesFromFile`.

**Expected output:** the modes of the file, each bad value as `pro`.

### Pass on

The model action is `passOn`.

`e.props.hasSurvey` is true. The hook returns the tree of `next(e)` as it came.

**Invariants:** `noRowInSurvey`, `belowKept`.

**Expected output:** the band holds the tree of `next(e)` and no `writing-mode` row.

### Draw row

The model action is `drawRow`.

The hook calls `next(e)` once. It returns a column `Box`: its own row first, then the tree of `next(e)` if it is an object. If `next(e)` gives no object, the row is the whole tree.

The row has the width `e.props.bodyColumns`, with `justifyContent="space-between"`: `Writing`, the `reply` and `docs` buttons at the left, and `⚙ config` at the right. The full width keeps `⚙ config` from being cut off.

`plan-rounds` puts the tree of `next(e)` above its own row (R2 of its component `pane-button`). So in either load order of the two harness mods, this row is the top row. The model holds both orders in `outer`: the run `roundsOuterTest` has `plan-rounds` as the outer mod.

**Invariants:** `ownRowFirst`, `belowKept`.

**Expected output:** the `writing-mode` row, then the tree of `next(e)`.

### Cycle

The model action is `cycle`.

A press reads the file again by `load($)`, moves the pressed kind to the next mode (`off`, `casual`, `pro`, then `off`), and writes both kinds. The other kind is written as read, so a press does not undo a change that another session made. A bad value is read as `pro`, so it is written as `pro`.

**Invariants:** `fileWrittenClean`.

**Expected output:** the file holds the new mode of the pressed kind and the mode of the other kind as read.

### Compose

The model action is `compose`.

The `prompt.compose` hook reads the file by `load($)`, then adds one section for each kind in `casual`. The engine may keep a `scope: 'session'` section for the session. So the hook reads the file on each compose, and the test composes three times, with the file set to casual and back to pro between.

**Invariants:** `casualOnly`.

**Expected output:** a casual section for each kind whose mode is `casual`, and none else.

### Toggle pane

The model action is `togglePane`.

A press of `⚙ config` calls `toggle`. If `$.ui.panes()` lists the pane `writing-check`, it calls `$.ui.close({ id: 'writing-check' })`. Else it opens the pane and runs `writing-check.py report`, as before. `/writing-check` only opens the pane: it calls the open alone (R12).

**Invariants:** `configToggles`, `paneOnlyByConfig`.

**Expected output:** the pane open if it was closed, else closed.

### Close pane

The model action is `closePane`.

A `ui.open` hook sees the open of a pane by another plugin. If its id is not `writing-check`, the hook calls `$.ui.close({ id: 'writing-check' })`, then `next(e)`, so the other pane opens. A close of a pane that is not open does nothing. The hook does not see this mod's own opens, since a call runs through every hook but its caller's (R10 of the `mod` level).

**Invariants:** `onePane`.

**Expected output:** this mod's pane is closed, and the other pane opens.

## Build checks

The build is code: a mod. Its tests are in `.claude/skills/writing-mode/hooks/register.test.tsx`, run by `claude plugin test .claude/skills/writing-mode`. The tests of R1, R2, R8, R9, R10 and R12 stay, except one: the test that a saved mode is read at session start becomes `other session`, since no read at start is left.

| Test | What it checks | Invariant or output |
|---|---|---|
| `bad file` | a file that does not parse, or a value that is not a mode, shows `pro` | `modesFromFile`, Read modes |
| `other session` | after the file changes on disk, the next draw shows the new modes | `modesFromFile` |
| `press reads the file` | a press moves on from the file's mode and keeps the other kind as the file had it | `fileWrittenClean`, Cycle |
| `compose reads the file` | three composes, with the file set to `casual` and back to `pro`: only the second has the casual section | `casualOnly`, Compose |
| `survey` | with `hasSurvey`, the band is the tree of `next(e)` alone | `noRowInSurvey`, Pass on |
| `top row` | with a tree from `next(e)` that holds a `Rounds` row, the `writing-mode` row comes first, with `⚙ config` | `ownRowFirst`, Draw row |
| `beneath shows` | the button of a mod beneath is in the band | `belowKept` |
| `config toggle` | a press of `⚙ config` opens the pane, a second press closes it, and a third opens it again | `configToggles`, Toggle pane |

Rules no test can see:

- The live order of `writing-mode` and `plan-rounds` in a session. `claude plugin test` loads one mod. The user loads both in a live session, in both orders.
- That `⚙ config` is not cut off on a narrow band. The user checks it in a live session.
- That the pane of another harness mod closes this one. The test kit loads one plugin, so The user checks it live.
- The case where `next(e)` gives no object: the kit skips a stand-in that returns no tree.
- That the engine runs `prompt.compose` at each turn. The test calls it three times: pro, casual, then pro again. The user checks in a live session that a press shows in the next reply.
- No redraw loop: a draw writes no state. The user checks in a live session that the band does not flicker.

- **Model checks:** `npx quint run plans/global/components/mod/components/writing-mode/writing-mode.qnt --main=writingMode --invariant=allInvariants` checks all nine invariants in every state of a walk: `modesFromFile`, `fileWrittenClean`, `ownRowFirst`, `belowKept`, `noRowInSurvey`, `casualOnly`, `configToggles`, `onePane`, `paneOnlyByConfig`. The same command with `--invariant=neverCycles` must report a violation. The runs are `drawTest`, `aloneTest`, `surveyTest`, `badTest`, `cycleTest`, `cycleBadTest`, `composeTest`, `roundsOuterTest`, `toggleTest`, `toggleCloseTest`, `onePaneTest` and `safetyTest`. The moves `startWith`, `openWith` and `stay` set up an event and keep the variables for the runs.

## Coverage

| Requirement | Model part or check |
|---|---|
| R1 | built. `cycle` and `fileWrittenClean` hold its press, test `press reads the file` |
| R2 | built. `compose` and `casualOnly`, test `compose reads the file` |
| R12 | `togglePane`, `configToggles`, `paneOnlyByConfig`, the runs `toggleTest` and `toggleCloseTest`, test `config toggle`. The report in the pane is built and its tests stay. |
| R10 of the `mod` level | `closePane`, `onePane`, the run `onePaneTest`. No test: the test kit cannot open a pane for a second plugin. The user checks it live. |
| R8 | `readModes`, `modesFromFile`, `fileWrittenClean`, the runs `badTest` and `cycleBadTest`, tests `bad file`, `other session`, `press reads the file` and `compose reads the file` |
| R9 | `ownRowFirst`, the run `roundsOuterTest`, test `top row` |
| R10 | `passOn`, `drawRow`, `belowKept`, `noRowInSurvey`, the runs `aloneTest` and `surveyTest`, tests `survey` and `beneath shows` |
| close_pane | the end of the run: see Risks |
| compose | the end of the run: see Risks |
| cycle | the end of the run: see Risks |
| draw_row | the end of the run: see Risks |
| pass_on | the end of the run: see Risks |
| toggle_pane | the end of the run: see Risks |

## Risks

- **A read at each draw.** The band draws often. A read of a small file is fast, but if it is slow, the band lags. The build reads it with `$.fs.read`, which does not start a process.
- **Two sessions press at once.** Both read, both write. The last write wins for the pressed kind. Each keeps the other kind as read, so at most one press is lost.
- **The hook crashes on a bad file.** `def mode` of `.claude/hooks/writing-check.py` fails on valid JSON that is not an object. That is outside the `Builds:` line of this level. It goes to the `writing-check` plan.
- **A mod from outside the harness.** It can load first and draw above this row, which R9 allows.
- **The order with `plan-rounds`.** The top row holds only if `plan-rounds` keeps its R2 of `components/pane-button/`.

## Appendix

- The band research: `personal/claude-research/staging/2026-10-28-mod-band/mod-band.staging.md`, Q2 to Q5.
- The load order research: `personal/claude-research/staging/2026-10-28-mod-order/mod-order.staging.md`.
- The mode reader of the hook: `.claude/hooks/writing-check.py`, `MODE_FILE` and `def mode`.
