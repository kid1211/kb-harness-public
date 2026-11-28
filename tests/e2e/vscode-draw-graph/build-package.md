# vscode-draw-graph: a fresh clone builds the extension package

## Covers

- `vscode-draw-graph/`
- `.claude/lib/draw-graph/`
- `.claude/lib/emoji-bullets/`
- `.claude/lib/palette/`
- `.claude/lib/plan-preview/`

## Setup

1. Make a temp folder `$T`.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test. Then run `npm ci` in `$T/h`.
3. Put a stub `code` in `$T/bin/code` that logs each call to `$T/code.log` and exits 0. The real VS Code stays as it is.

## Steps

1. In `$T/h`, run `node --test` on each of these files: `.claude/lib/draw-graph/tests/parse.test.js`, `.claude/lib/draw-graph/tests/import-graph.test.js`, `.claude/lib/emoji-bullets/tests/emoji-bullets.test.js` and `.claude/lib/plan-preview/tests/plan-preview.test.js`.
2. In `$T/h`, run `PATH=$T/bin:$PATH bash vscode-draw-graph/build.sh`.
3. Run `unzip -l $T/h/vscode-draw-graph/draw-graph-preview.vsix`.

## Expected

1. Each run of step 1 prints `fail 0`.
2. Step 2 prints `Packaged: draw-graph-preview.vsix` and ends with exit code 0.
3. `$T/code.log` holds one call: `--install-extension draw-graph-preview.vsix --force`.
4. The list of step 3 holds `extension/extension.js`, `extension/preview.bundle.js`, `extension/markdown-diff.js` and `extension/plan-preview.js`.
5. If `$T/h/.claude/skills/id-hover/` does not exist, the list holds no `extension/id-core.js`, and `$T/h/vscode-draw-graph/id-cards.css` is empty.
6. `$T/h/vscode-draw-graph/preview.bundle.js` starts with the Cytoscape licence comment.

## Cleanup

1. Delete `$T`.
