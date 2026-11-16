#!/usr/bin/env bash
# Build the extension and install it into VS Code.
# VS Code loads each preview script with `async`, so their order is not fixed. One bundle
# keeps Cytoscape and ELK before draw-graph.js, and draw-graph.js before preview.js.
set -euo pipefail
cd "$(dirname "$0")"
# Cytoscape and ELK come from the versions that package.json pins, like marked and jsdiff below.
nm=$(node -p 'require.resolve("cytoscape").replace(/\/cytoscape\/.*/, "")')
cp "$nm/cytoscape/dist/cytoscape.min.js" cytoscape.min.js
cp "$nm/elkjs/lib/elk.bundled.js" elk.bundled.js
for f in cytoscape.min.js elk.bundled.js ../.claude/lib/draw-graph/draw-graph.js ../.claude/lib/code-reference/code-reference.js ../.claude/lib/plan-preview/plan-preview.js preview.js; do
  cat "$f"; printf '\n;\n'
done > preview.bundle.js
cp ../.claude/lib/palette/palette.css palette.css
# extension.js resolves import-graph blocks with it, in node.
cp ../.claude/lib/draw-graph/import-graph.js import-graph.js
# extension.js and the diff page show an emoji at the start of a list item as its bullet.
cp ../.claude/lib/emoji-bullets/emoji-bullets.js ../.claude/lib/emoji-bullets/emoji-bullets.css .
# The rendered Markdown diff: markdown-diff.js and the marked and jsdiff that package.json pins.
# node finds them in the harness's node_modules, from a worktree too.
cp ../.claude/lib/markdown-diff/markdown-diff.js ../.claude/lib/markdown-diff/markdown-diff.css .
# Cmd+Shift+C: the extension runs it in node, the diff page and the preview bundle in the page.
cp ../.claude/lib/code-reference/code-reference.js .
# plan-preview: extension.js runs it in node, the preview bundle in the page, with its stylesheet.
cp ../.claude/lib/plan-preview/plan-preview.js ../.claude/lib/plan-preview/plan-preview.css .
# id-hover: the shared core.mjs of the mod as a script for node and the page, and the drawing of its cards.
# A checkout with no id-hover, such as the public one, builds with no cards: extension.js then loads none.
if [ -f ../.claude/skills/id-hover/core.mjs ] && [ -d ../.claude/lib/id-hover ]; then
  node ../.claude/lib/id-hover/to-script.js ../.claude/skills/id-hover/core.mjs id-core.js
  cp ../.claude/lib/id-hover/id-cards.js ../.claude/lib/id-hover/id-cards.css .
else
  rm -f id-core.js id-cards.js && : > id-cards.css
fi
cp "$nm/marked/marked.min.js" marked.min.js
cp "$nm/diff/dist/diff.min.js" diff.min.js
npx -y @vscode/vsce@3.6.0 package --allow-missing-repository --skip-license -o draw-graph-preview.vsix
code --install-extension draw-graph-preview.vsix --force
echo "Installed. In VS Code, run 'Developer: Reload Window'."
