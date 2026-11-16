// Run: node --test .claude/lib/draw-graph/tests/check.test.js
// Positive controls for DrawGraph.check: each rule is shown to fire on a graph that
// breaks it, and to stay quiet on one that does not. Needs Chromium and the network.
const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");
const { chromium } = require("@playwright/test");

let browser, page;
test.before(async () => {
  browser = await chromium.launch();
  page = await browser.newPage({ viewport: { width: 1150, height: 1000 } });
  await page.setContent('<!doctype html><body style="margin:0"><div id="g" style="width:1050px"></div></body>');
  await page.addScriptTag({ url: "https://cdn.jsdelivr.net/npm/cytoscape@3.34.3/dist/cytoscape.min.js" });
  await page.addScriptTag({ url: "https://cdn.jsdelivr.net/npm/elkjs@0.12.0/lib/elk.bundled.js" });
  await page.addScriptTag({ path: path.join(__dirname, "..", "draw-graph.js") });
});
test.after(() => browser.close());

// Draw text in a fresh box, run move(cy) to spoil the layout, and return check's lines.
const run = (text, move = "") => page.evaluate(async ([text, move]) => {
  const old = document.getElementById("g"), box = old.cloneNode(false);
  old.replaceWith(box);
  const cy = await DrawGraph.draw(box, text);
  new Function("cy", move)(cy);
  return DrawGraph.check(cy);
}, [text, move]);

const chain = (n, label) => Array.from({ length: n }, (_, i) => `n${i} -> n${i + 1}${label ? ` [${label}]` : ""}`).join("\n");

test("a small clean graph passes", async () => {
  assert.deepEqual(await run("a -> b [x], c\nb -> d"), []);
});

test("R2: a node moved onto another is an overlap", async () => {
  const out = await run("a -> b, c", "cy.$('#c').position(cy.$('#b').position());");
  assert.ok(out.some(l => l.startsWith("R2 overlap")), out.join("\n"));
});

test("R2: a node moved onto a link is a crossing", async () => {
  const out = await run("a -> b\nc -> d", `const s = cy.$('#a').position(), t = cy.$('#b').position();
    cy.$('#c').position({ x: (s.x + t.x) / 2, y: (s.y + t.y) / 2 });`);
  assert.ok(out.some(l => l.startsWith("R2 crossing: link a -> b crosses node")), out.join("\n"));
});

test("R3 and R4: a long chain shrinks, so it is too tall and its text too small", async () => {
  const out = await run(chain(24, "next"));
  assert.ok(out.some(l => l.startsWith("R3 ratio")), out.join("\n"));
  assert.ok(out.some(l => l.startsWith("R4 density")), out.join("\n"));
});

test("R3: a small wide graph that does not shrink passes", async () => {
  assert.deepEqual(await run("root -> a, b, c, d, e"), []);
});
