// Run: node --test .claude/lib/draw-graph/tests/parse.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { parse, draw } = require("../draw-graph.js");

function quiet(fn) {
  const warn = [], old = console.warn;
  console.warn = (...a) => warn.push(a.join(" "));
  try { return [fn(), warn]; } finally { console.warn = old; }
}

test("begin, end, skill and hook lines mark a node's kind", () => {
  const g = parse("begin a\nend c\nfail d\nskill s\nhook h\na -> b, s, h\nb -> c, d");
  const by = Object.fromEntries(g.nodes.map(n => [n.id, n]));
  assert.deepEqual([by.a.kind, by.c.kind, by.d.kind, by.s.kind, by.h.kind, by.b.kind], ["begin", "end", "fail", "skill", "hook", undefined]);
  assert.deepEqual([by.a.label, by.s.label], ["a", "s"]);
  assert.deepEqual([by.s.external, by.h.external, by.a.external], [true, true, undefined]);
  assert.deepEqual(parse("end -> b").edges.map(e => [e.source, e.target]), [["end", "b"]]);
});

test("an external line marks its nodes as components", () => {
  const g = parse("external helper tool\nstart -> helper\nstart -> step");
  const ext = Object.fromEntries(g.nodes.map(n => [n.id, !!n.external]));
  assert.deepEqual(ext, { helper: true, tool: true, start: false, step: false });
  assert.deepEqual(parse("external -> b").edges.map(e => [e.source, e.target]), [["external", "b"]]);
});

test("each line type reads, and an unread line warns", () => {
  const [g, warn] = quiet(() => parse(`# comment
[Backend] api worker
api: Serves the REST API
api -> db [reads and writes], cache
web_app -> api [calls]
nonsense line here`));
  assert.deepEqual(g.nodes.map(n => n.id).sort(), ["api", "cache", "db", "web_app", "worker"]);
  assert.deepEqual(g.groups, ["Backend"]);
  const api = g.nodes.find(n => n.id === "api");
  assert.equal(api.parent, "Backend");
  assert.equal(api.desc, "Serves the REST API");
  assert.equal(g.nodes.find(n => n.id === "web_app").label, "web app");
  assert.deepEqual(g.edges, [
    { source: "api", target: "db", label: "reads and writes" },
    { source: "api", target: "cache", label: undefined },
    { source: "web_app", target: "api", label: "calls" },
  ]);
  assert.equal(warn.length, 1);
});

test("a comma inside a label does not split the targets", () => {
  assert.deepEqual(parse("a -> b [reads, writes], c").edges,
    [{ source: "a", target: "b", label: "reads, writes" }, { source: "a", target: "c", label: undefined }]);
});

test("nodes are ordered by the first link line that names them", () => {
  const g = parse("[G] late\nlate: listed first, linked last\nx -> y\ny -> late");
  const ord = Object.fromEntries(g.nodes.map(n => [n.id, n.ord]));
  assert.deepEqual(ord, { late: 2, x: 0, y: 1 });
});

test("a state box has a run line, and in and out from its links (R26)", () => {
  const g = parse("to_design.run: p-design\nto_design: hover text\nb.run: p-req:grill, fern-decide\nc.run: fern-decide\nup_one -> to_design\nspec:check? -> to_design [x]\nto_design -> b, c, b");
  const n = g.nodes.find(x => x.id === "to_design");
  assert.equal(n.label, "to design\n----\nrun: [p-design]\nin: [up one, spec:check]\nout: [p-req:grill, fern-decide]");
  assert.equal(parse("end e\ne.run: spec:stop\nx -> e").nodes.find(x => x.id === "e").label.split("\n")[0], "\u2800".repeat(2) + " " + "e");
  assert.equal(n.state, true);
  assert.equal(n.desc, "hover text");
  const u = g.nodes.find(x => x.id === "up_one");
  assert.deepEqual([u.label, u.state], ["up one", undefined]);
});

test("a loop inside a state box stays out of its in and out (R27)", () => {
  const n = parse("a.run: p-req:grill\nx -> a\na -> a [loop: grill one]\na -> b").nodes.find(x => x.id === "a");
  assert.equal(n.label, "a\n----\nrun: [p-req:grill]\nin: [x]\nout: [b]");
});

test("it loads outside a browser", () => {
  assert.equal(typeof draw, "function");
});

// graph-colours: a colour line, by palette name (plans/draw-graph/components/graph-colours/graph-colours.qnt).
test("a colour line gives a node its text and fill, and a link its line and label", () => {
  const g = parse("a -> b [go]\na -> c\ncolor a text=tan fill=midnight\ncolor a -> b line=slate-blue label=light-blue");
  const a = g.nodes.find(n => n.id === "a");
  assert.deepEqual(a.colors, { text: "#D2B48C", fill: "#191970" });
  const [ab, ac] = g.edges;
  assert.deepEqual(ab.colors, { line: "#4A6A88", label: "#A8D8EA" });
  assert.equal(ac.colors, undefined, "a link the line does not name keeps its colour");
});

test("a graph with no colour line keeps every colour of its kind", () => {
  const g = parse("external a\na -> b");
  assert.ok(g.nodes.every(n => n.colors === undefined) && g.edges.every(e => e.colors === undefined));
  assert.deepEqual(parse("color -> b").edges.map(e => [e.source, e.target]), [["color", "b"]], "a node named color still links");
});

test("a bad colour line throws: a dark colour on text or a line, firebrick, a hex value, an unknown name or node", () => {
  for (const [line, word] of [["color a text=navy", "navy"], ["color a -> b line=midnight", "midnight"], ["color a fill=firebrick", "firebrick"],
    ["color a -> b label=#ff0000", "#ff0000"], ["color a fill=pink", "pink"], ["color a size=tan", "size"], ["color zz text=tan", "zz"],
    ["color a -> zz line=tan", "zz"], ["color a text=toString", "toString"], ["color a __proto__=tan", "__proto__"],
    ["color constructor text=tan", "constructor"], ["color a text=tan=x", "tan=x"], ["color a -> a line=tan", "loop"]])
    assert.throws(() => parse("a -> b\na -> a\n" + line), e => e.message.includes(word) && e.message.includes(line) && e.message.includes("line 3"), line);
});

test("a link line from a node named color, with two spaces, still links", () => {
  assert.deepEqual(parse("color  -> b").edges.map(e => [e.source, e.target]), [["color", "b"]]);
});
