#!/usr/bin/env node
// Draws each ```graph block in markdown files the way VS Code's preview does, top to
// bottom in a 1050 px wide box, and prints every layout rule the drawing breaks
// (plans/draw-graph/components/graph-check). Exit 0: all pass, or the check could
// not run (no network); 1: a rule is broken.
//
//   node .claude/lib/draw-graph/check.js FILE.md ...
const fs = require("node:fs");
const path = require("node:path");
const { resolve } = require("./import-graph.js");
let chromium;
try { ({ chromium } = require("@playwright/test")); }
catch { console.log("graph check did not run: no Playwright; run `npm ci` in the harness"); process.exit(0); }

const LIBS = ["https://cdn.jsdelivr.net/npm/cytoscape@3.34.3/dist/cytoscape.min.js",
  "https://cdn.jsdelivr.net/npm/elkjs@0.12.0/lib/elk.bundled.js"];
const WIDTH = 1050; // the viewer's article width, less its padding

function blocks(file) {
  const out = [], lines = fs.readFileSync(file, "utf8").split("\n");
  for (let i = 0; i < lines.length; i++) {
    if (!/^\s*```graph\s*$/.test(lines[i])) continue;
    const start = i + 1;
    while (++i < lines.length && !/^\s*```\s*$/.test(lines[i]));
    // An import-graph block is checked as the graph it draws (R18).
    const text = resolve(lines.slice(start, i).join("\n"), file);
    out.push(text instanceof Error ? { line: start, error: text.message } : { line: start, text });
  }
  return out;
}

(async () => {
  const files = process.argv.slice(2).map(f => [f, blocks(f)]).filter(([, b]) => b.length);
  if (!files.length) return;
  const browser = await chromium.launch();
  let bad = 0;
  try {
    const page = await browser.newPage({ viewport: { width: WIDTH + 100, height: 1000 } });
    await page.setContent(`<!doctype html><body style="margin:0"><div id="g" style="width:${WIDTH}px"></div></body>`);
    try { for (const url of LIBS) await page.addScriptTag({ url }); }
    catch { console.log("graph check did not run: the libraries need the network."); return; }
    await page.addScriptTag({ path: path.join(__dirname, "draw-graph.js") });
    for (const [file, bs] of files) for (const b of bs) {
      if (b.error) { bad = 1; console.log(`${file}:${b.line}: ${b.error}`); continue; }
      if (!b.text.trim()) continue;   // a blank architecture.md: nothing to draw yet
      const problems = await page.evaluate(async text => {
        const old = document.getElementById("g"), box = old.cloneNode(false);
        old.replaceWith(box);
        const warn = [], cw = console.warn;
        console.warn = (...a) => warn.push(a.join(" "));
        try { return [...warn, ...DrawGraph.check(await DrawGraph.draw(box, text))]; }
        catch (e) { return ["draw failed: " + e.message]; }
        finally { console.warn = cw; }
      }, b.text);
      if (!problems.length) continue;
      bad = 1;
      console.log(`${file}:${b.line}: the graph breaks ${problems.length} rule(s):`);
      for (const p of problems) console.log("  " + p);
    }
  } finally { await browser.close(); }
  process.exitCode = bad;
})();
