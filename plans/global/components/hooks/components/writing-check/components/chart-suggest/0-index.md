# Chart suggest

## Goal

- Know which charts Claude's `dataviz` skill offers, and keep a scored catalog of them.
- When Claude writes a doc, say if the doc should hold a chart, and which one.
- The research behind it is the topic `plans/research-only/components/graph-output-value/`, Q9 to Q13 of its staging page.

8 requirements, 0 components. Draft.

Builds: `personal/claude-research/staging/2026-10-25-chart-catalog/chart-catalog.staging.md` (the catalog page, in the `personal` KB), `scripts/chart-catalog.py`, `.claude/hooks/writing-check.py` (the chart rule: `chart_signals`, `chart_notes`)
Uses: the `dataviz` skill bundled with Claude Code, `writing-check`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** I have one scored catalog of the chart forms that dataviz offers.
  Decision: pending
  Built: 0 of 3
  What Claude thinks the user means: A single reference page I can trust for picking a chart.
- **F2.** I learn when dataviz adds a form the catalog lacks.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: The catalog does not go stale.
- **F3.** After a docs edit, Claude suggests a chart when the data fits one.
  Decision: pending
  Built: 0 of 4
  What Claude thinks the user means: A nudge to chart numbers, in any table-like shape.

## Open questions

1. ⚠️ major: a catalog page with no "Signal table" heading raises IndexError in `chart_signals` (writing-check.py:141), and the hook returns 0 with no output and no `chart/missing` line. The graph sends that case to `missing`. A build fix: return None, and run the chart rule in its own `try`. (Frieren, 2026-11-02)
2. ⚠️ major: the page sets only the form and the reason of a signal. The tests are fixed in code (`table_signal`, `CHART_WORDS`), so a new row changes nothing. R7 says a change to the page changes the check. Claude picks: R7 and the design say only the form and reason come from the page (Claude, 2026-11-02, recommended). Reword R7 in the next round.
3. ⚠️ major: no invariant of the model can fail, and no test runs the hook twice with no catalog to check "logged once". The build adds that test.
4. ⚠️ minor: notes are capped at 3. A chart note rides in the block reason of a failing edit. Inline code and `~~~` fences are scanned. A linked `.csv` that is missing still matches the words rule. R5 says "the docs mode of R9" and means `writing-check` R9. `chart-catalog.py` exits 1 for two causes, and a missing `components.md` shows a traceback.

## Research questions

### the user

None.

### Claude

1. answered [Which way says best whether a doc's content needs a chart?](../../../../../../../../personal/claude-research/staging/2026-10-25-chart-suggest/detect-chart-need.staging.md#q1-which-way-says-best-whether-a-docs-content-needs-a-chart)
2. answered [Where does the bundled dataviz skill sit on disk?](../../../../../../../../personal/claude-research/staging/2026-10-25-chart-suggest/detect-chart-need.staging.md#q2-where-does-the-bundled-dataviz-skill-sit-on-disk)
