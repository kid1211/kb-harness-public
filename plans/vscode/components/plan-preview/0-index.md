# Plan preview

## Goal

In VS Code's Markdown preview, a plan level reads well. The parts of each state fold away, a research answer opens in a big popup, a hover on a question shows its short answer, and the user marks each answer agree or disagree in place.

9 requirements, 0 components. Draft.

Builds: `.claude/lib/plan-preview/`, its calls in `vscode-draw-graph/extension.js` and `vscode-draw-graph/preview.js`, its lines in `vscode-draw-graph/build.sh` and `vscode-draw-graph/package.json`, and its styles in `vscode-draw-graph/preview.css`
Uses: VS Code's extension API, the palette in `.claude/lib/palette/`

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** The parts of each state fold away in the preview.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: I want a design page short enough to read.
- **F2.** A research answer opens in a big popup.
  Decision: pending
  Built: 0 of 2
  What Claude thinks the user means: I want the full answer without leaving the page.
- **F3.** I mark each answer agree or disagree in place, and see its mark.
  Decision: pending
  Built: 0 of 2
  What Claude thinks the user means: I want my feedback written back to the file.
- **F4.** I can view only the states, and the logic is testable without VS Code.
  Decision: pending
  Built: 0 of 3
  What Claude thinks the user means: I want a compact view and tests that run in node.

## Open questions

- ⚠️ Research questions 1 to 3 stay open: each answer has confidence 2 and needs a live VS Code test, which a fork cannot run. (Claude, 2026-11-02)
- ⚠️ The Frieren review of the R416 design did not run. The run was a fork, and a fork cannot start an agent. Run `/spec` on this level again for the designed check. (Claude, 2026-11-02)

## Research questions

### User

None.

### Claude

1. open [How does the popup get the text of the answer page?](../../../../../personal/claude-research/staging/2026-10-24-p-spec-flow/preview-mechanics.staging.md#q2-how-does-the-popup-get-the-text-of-the-answer-page)
2. open [How does a big popup open and close, when hover cannot keep it open?](../../../../../personal/claude-research/staging/2026-10-24-p-spec-flow/preview-mechanics.staging.md#q3-how-does-a-big-popup-open-and-close-when-hover-cannot-keep-it-open)
3. open [How does a preview setting reach the preview?](../../../../../personal/claude-research/staging/2026-10-24-p-spec-flow/preview-mechanics.staging.md#q4-how-does-a-preview-setting-reach-the-preview)
4. answered [Can a click in the preview write into a file?](../../../../../personal/claude-research/staging/2026-10-24-p-spec-flow/preview-mechanics.staging.md#q1-can-a-click-in-the-preview-write-into-a-file)
