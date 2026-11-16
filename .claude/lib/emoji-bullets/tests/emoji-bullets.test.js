// Run: node --test .claude/lib/emoji-bullets/tests/emoji-bullets.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { marked } = require("marked");
const { apply } = require("../emoji-bullets.js");

const md = text => apply(marked.parse(text));

test("an emoji at the start of a list item replaces the dot, once, at every depth", () => {
  const out = md("- 🎯 **R1. A:** x\n  - 🚀 nested\n- plain\n- a 🌟 inside\n");
  assert.match(out, /<li style="list-style-type: '🎯 '" data-legend="[^"]*"><span class="eb-legend"[\s\S]*?<\/span><\/span><strong>R1/);
  assert.match(out, /<li style="list-style-type: '🚀 '">nested/);
  assert.match(out, /<li>plain/);
  assert.match(out, /<li>a 🌟 inside/);
  assert.equal(out.match(/🎯/g).length, 3);   // the marker, the legend attribute and the legend
});

// A fixture of the preview text. req-active.md of a moved level has the same
// ## Requirements heading and the same items, so it gets the same legend.
test("a requirement item and the Requirements heading get the legend, other items do not", () => {
  const out = md("## Requirements\n\n- ✅ **R2. B:** y\n- ✅ done, not a requirement\n");
  assert.match(out, /<h2 data-legend="🎯 todo[^"]*&#10;🌟 researched[^"]*&#10;🚀 designed[^"]*&#10;✅ built[^"]*">Requirements<span class="eb-legend"/);
  assert.match(out, /<li style="list-style-type: '✅ '" data-legend=/);
  assert.match(out, /<li style="list-style-type: '✅ '">done/);
});

test("on an item, the row of its own status is marked, and on the heading no row is", () => {
  const out = md("## Requirements\n\n- 🚀 **R3. C:** z\n");
  assert.match(out, /<span class="eb-row eb-on">🚀 designed/);
  assert.equal(out.match(/eb-on/g).length, 1);
});

test("the attributes of the VS Code preview are kept", () => {
  assert.equal(apply('<li data-line="3" class="code-line">🚀 x</li>'),
    `<li data-line="3" class="code-line" style="list-style-type: '🚀 '">x</li>`);
  assert.match(apply('<h2 data-line="9" class="code-line" id="requirements">Requirements</h2>'),
    /^<h2 data-line="9" class="code-line" id="requirements" data-legend="🎯/);
});

test("an emoji item that is no requirement ends with its bullet and no legend", () => {
  const out = md("- 🎯 not a requirement\n");
  assert.match(out, /<li style="list-style-type: '🎯 '">not a requirement/);
  assert.equal(out.includes("eb-legend"), false);
});

test("a page given twice to apply() is not changed the second time", () => {
  const once = md("## Requirements\n\n- 🚀 **R3. C:** z\n- 🎯 plain\n");
  assert.equal(apply(once), once);
});

// Frieren, designed check 2026-11-02: an item with a style keeps it, with no bullet (1-design.md Bulleted).
test("an item that already has a style is left as it is", () => {
  const li = `<li style="color: red">🚀 x</li>`;
  assert.equal(apply(li), li);
});
