# Writing mode

## Goal

The writing-mode mod: the buttons above the prompt that set the writing-check mode of replies and docs, and the pane with the writing-check report. Draft.

Builds: the `writing-mode` mod in `.claude/skills/writing-mode/`, and its line in the Tests of `CLAUDE.md`
Uses: the mode file and the `report` command of `.claude/hooks/writing-check.py`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** I set the writing mode with buttons above the prompt.
  Decision: pending
  Built: 2 of 5
  What Claude thinks the user means: I want to switch replies and docs between off, casual and pro, the same on every session.
- **F2.** I read the writing-check report in a pane.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: I want the report one press away.
- **F3.** The domains button of the folder pane sits in my writing line, next to config. Its label is `⧉ domain`. The status line names the domain.
  Decision: keep
  Built: 0 of 1
  What Claude thinks the user means: I want one line of buttons above the prompt, not two.

## Open questions

1. ✅ Does the Tests line in `CLAUDE.md`, which `Builds:` names, need its own requirement?
   - Answer: no, the `Builds:` line is enough. Closed 2026-10-28 by the user.
2. ✅ How does `writing-mode` get the top row of the band, when the load order of mods sets it?
   - Answer: research what sets the load order, and the design uses it. Closed 2026-10-28 by the user.
3. ✅ Is the writing mode one setting per machine or one per session?
   - Answer: per machine, and each session reads the file again before it draws. R7 changed into R8. Closed 2026-10-28 by the user.
4. ✅ R6: should R6 promise the top row only among the harness mods? No rule found beats a mod from elsewhere that loads first, such as one in the session's mods folder ([Q1](../../../../../../personal/claude-research/staging/2026-10-28-mod-order/mod-order.staging.md#q1-what-sets-the-load-order-of-mods-so-that-writing-mode-is-the-outer-mod)). Recommendation: yes, narrow R6 and R8 of `mod` to the harness mods.
   - Answer: yes, narrow R6 and R8 of `mod` to the harness mods. R6 changed into R9 and R10, and mod R8 into R9. Closed 2026-10-28 by the user.
5. ✅ R6: should R6 be split? It holds the top row, passing on `next(e)`, the empty `next(e)` case and the survey case. Recommendation: yes, into two: the top row, and passing the band on with its empty and survey cases.
   - Answer: yes, into R9 (the top row) and R10 (passing the band on, with its empty and survey cases). Closed 2026-10-28 by the user.
6. ✅ R6: is Option A, a rule on `plan-rounds` to put the tree of `next(e)` above its own row, acceptable ([Q2](../../../../../../personal/claude-research/staging/2026-10-28-mod-order/mod-order.staging.md#q2-how-can-writing-mode-get-the-top-row-when-the-order-is-not-known))? Recommendation: yes, and add the rule as a requirement of the `plan-rounds` level.
   - Answer: yes. `plan-rounds` holds it in R2 of its component `pane-button`. Closed 2026-10-28 by the user.
7. ✅ The third requirements review found two edge cases of R8 and one width point. Do they need new requirements?
   - Answer: no. Each is how R8 and parent R6 are met, so `p-design` handles each one: a press reads the file again before it writes, a mode that is not `off`, `casual` or `pro` counts as `pro`, and the row must not cut off `⚙ config` in a narrow band. Closed 2026-10-28 by Fern.
8. ⚠️ major: `1-design.md` named `--invariant=allInvariants` and the model had none. Fixed in this round: the model defines `allInvariants` and the control `neverCycles` fails. (Frieren, 2026-11-02)
9. ⚠️ minor: the code of `toggle` and the `ui.open` hook never reads the mode file, though the graph sends every event through `read_modes`. `ui.open` closes the pane for any other plugin, and the design says another harness mod. Claude keeps both as they are, since neither changes a mode (Claude, 2026-11-02, recommended).
10. ⚠️ minor: `passOn` assumes `plan-rounds` draws no row in a survey. `def mode` in `writing-check.py` crashes on JSON that is not an object, so R8 is not met for that case until the `writing-check` plan fixes it. Whether the engine keeps a `scope: 'session'` casual section after a switch to `pro` is not shown by the test kit.

## Research questions

### User

None.

### Claude

1. answered R6: what sets the load order of mods, so that `writing-mode` is the outer mod and draws the top row? A name, an install place (`.claude/skills/`, a plugin, the session's mods folder) or a setting? [Q1](../../../../../../personal/claude-research/staging/2026-10-28-mod-order/mod-order.staging.md#q1-what-sets-the-load-order-of-mods-so-that-writing-mode-is-the-outer-mod): open. Only the tier is fixed. Inside the tier of what a person installs, the types give no rule, and two mods in `.claude/skills/` were not tested. Settled by open question 4: R9 holds only among the harness mods, so it needs no such rule.
2. answered R6: how can `writing-mode` draw the top row, if no rule sets the order? [Q2](../../../../../../personal/claude-research/staging/2026-10-28-mod-order/mod-order.staging.md#q2-how-can-writing-mode-get-the-top-row-when-the-order-is-not-known): done. A: the other harness mods put the tree of `next(e)` above their own row. B: one mod draws every harness row. Recommendation A.
