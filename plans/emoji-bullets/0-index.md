# Emoji bullets

## Goal

In rendered Markdown, a list item that starts with an emoji shows the emoji as its bullet, and a requirement shows the status legend on hover. A module on its own, so it can be removed in one step. 4 requirements, 0 components. Draft.

Builds: `.claude/lib/emoji-bullets/`, its `apply()` call in `vscode-draw-graph/extension.js` and `vscode-draw-graph/diff-view.js`, and its line in `vscode-draw-graph/build.sh`
Uses: nothing

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** A list item that starts with an emoji shows that emoji as its bullet.
  Decision: pending
  Built: 2 of 2
  What Claude thinks the user means: I want the emoji to replace the dot, so lists read cleanly.
- **F2.** I see what each status means when I hover over a requirement.
  Decision: pending
  Built: 2 of 3
  What Claude thinks the user means: I want a legend on hover, with my item's own status picked out.
- **F3.** I can remove the whole feature in one step.
  Decision: pending
  Built: 1 of 1
  What Claude thinks the user means: I want it in a single module, so dropping it is easy.

## Open questions

- ⚠️ built check 2026-11-02 (Frieren): the styled-item [major] is now a tested behaviour (`emoji-bullets.js:32`, test `:52`) that R1, the graph and the model lack. p-req should add the exception or the code should merge the style. minor: F2 Built count is stale, CSS size and white row have no test, emoji ZWJ and skin-tone sequences give only the first code point, a hover on a nested line shows the parent legend, IdCards runs before EmojiBullets and may unwrap the label ID.
- ⚠️ designed check 2026-11-02 (Frieren; p-build 2026-11-02 added a test that shows the code skips a styled item, as the design says. The gap stays for p-req: add the exception to R1, the graph and the model):
  - [major] `1-design.md:30` says an item that already has a `style` gets no bullet, but R1, the graph and the model have no such exception. Fix one of the three (a model flag, an R1 exception, or merge the style in code).
  - minor: `1-design.md:16` "any combination" is wrong (`initWith` constrains the flags). minor: the `done` link for the "apply twice" test is false (`done` is a stutter). minor: `bulletOnlyTest` missing from the run list. minor: `renderedTest` repeats `itemTest`. minor: `legendOnlyWhereAsked` checks nothing in Legend. minor: 0-index says "4 requirements" and "Draft." with five R and a built module. minor: `Builds:` omits the stylesheet entries R4 names.

## Research questions

### User

None.

### Claude

None.
