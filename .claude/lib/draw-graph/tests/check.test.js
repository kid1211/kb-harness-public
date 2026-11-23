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

// graph-edge-labels: a link's text sits on its link, and wraps past the width of "get-grocery-list".
const labelOf = (text, src, dst) => page.evaluate(async ([text, src, dst]) => {
  const old = document.getElementById("g"), box = old.cloneNode(false);
  old.replaceWith(box);
  const cy = await DrawGraph.draw(box, text), e = cy.edges(`[source="${src}"][target="${dst}"]`)[0];
  const b = e.boundingBox({ includeNodes: false, includeEdges: false, includeLabels: true });
  const pts = [e.sourceEndpoint(), ...(e.segmentPoints() || []), e.targetEndpoint()];
  const c = { x: (b.x1 + b.x2) / 2, y: (b.y1 + b.y2) / 2 };
  // The distance from the text's centre to the nearest segment of its link.
  const dist = Math.min(...pts.slice(1).map((q, i) => { const p = pts[i], dx = q.x - p.x, dy = q.y - p.y;
    const t = Math.max(0, Math.min(1, ((c.x - p.x) * dx + (c.y - p.y) * dy) / (dx * dx + dy * dy || 1)));
    return Math.hypot(p.x + t * dx - c.x, p.y + t * dy - c.y); }));
  const ctx = document.createElement("canvas").getContext("2d");
  ctx.font = `${Math.round(parseFloat(getComputedStyle(box).fontSize))}px "Helvetica Neue", Helvetica, sans-serif`;
  return { w: b.w, h: b.h, dist, max: ctx.measureText("get-grocery-list").width, check: DrawGraph.check(cy) };
}, [text, src, dst]);

test("graph-edge-labels inTheLine: a link's text sits on its link", async () => {
  const r = await labelOf("a -> b [calls]\nb -> c", "a", "b");
  assert.ok(r.dist < 2, `text centre is ${r.dist.toFixed(1)} px off its link`);
});

test("graph-edge-labels widthCapped, roomForText: a long link text wraps and the graph passes", async () => {
  const r = await labelOf("plan -> list [reads the plan and writes the grocery list]\nlist -> shop", "plan", "list");
  assert.ok(r.w <= r.max + 12, `text is ${r.w.toFixed(0)} px wide, max ${r.max.toFixed(0)}`);
  assert.ok(r.h > 16 * 2, `text is ${r.h.toFixed(0)} px tall, so it did not wrap`);
  assert.ok(r.dist < 2, `text centre is ${r.dist.toFixed(1)} px off its link`);
  assert.deepEqual(r.check, []);
});
