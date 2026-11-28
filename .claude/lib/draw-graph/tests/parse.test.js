// Run: node --test .claude/lib/draw-graph/tests/parse.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { parse, draw, ringPlace, dotSize } = require("../draw-graph.js");

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

// graph-center-layout noRingsLayered: catches a ring line that sets no ring, or a ring on a graph with none.
test("ring: a ring line sets the ring of each node it names", () => {
  const by = Object.fromEntries(parse("ring 0 a\nring 1 b c\na -> b, c\nd -> a").nodes.map(n => [n.id, n.ring]));
  assert.deepEqual(by, { a: 0, b: 1, c: 1, d: undefined });
  assert.ok(parse("a -> b").nodes.every(n => n.ring === undefined));
});

// graph-center-layout ringsInOrder, moreLinksNearer: catches an outer ring nearer the center than an inner one,
// a node with more links further out in its ring, or two node boxes on top of each other.
test("ringPlace: rings in order, more links nearer, no overlap", () => {
  const box = (id, ring) => ({ id, ring, w: 120, h: 34 });
  const nodes = [box("hub", 0), box("x", 1), box("y", 1), box("z", 1), box("lone", 1), box("r1", 2), box("r2", 2), box("ext", undefined)];
  const edges = [["x", "hub"], ["y", "hub"], ["x", "y"], ["x", "z"], ["r1", "x"], ["r2", "y"], ["ext", "x"], ["x", "hub"]];
  const p = ringPlace(nodes, edges), r = id => Math.hypot(p[id].x, p[id].y);
  const ring = k => nodes.filter(n => (n.ring ?? 3) === k).map(n => r(n.id));
  for (const k of [0, 1, 2]) assert.ok(Math.max(...ring(k)) < Math.min(...ring(k + 1)), `ring ${k} inside ring ${k + 1}`);
  assert.ok(r("x") < r("y") && r("y") < r("lone"), "more links, nearer the center");
  for (const a of nodes) for (const b of nodes) if (a.id < b.id)
    assert.ok(Math.abs(p[a.id].x - p[b.id].x) >= 120 || Math.abs(p[a.id].y - p[b.id].y) >= 34, `${a.id} and ${b.id} overlap`);
});

// graph-center-layout F2: catches a ring that spreads its nodes evenly, so a node lands far from the one it links to.
test("ringPlace: a node sits next to the node it links to, not an even share away", () => {
  const box = (id, ring) => ({ id, ring, w: 20, h: 20 });
  const nodes = [box("hub", 0), box("a", 1), box("b", 1), box("c", 1), box("d", 1)];
  const p = ringPlace(nodes, [["a", "hub"], ["b", "hub"], ["c", "hub"], ["d", "a"]]);
  const ang = id => Math.atan2(p[id].y, p[id].x), gap = Math.abs(((ang("d") - ang("a")) % (2 * Math.PI) + 3 * Math.PI) % (2 * Math.PI) - Math.PI);
  assert.ok(gap < Math.PI / 3, `d is ${(gap * 180 / Math.PI).toFixed(0)} degrees from a`);
});

// graph-colours F6: catches an external link drawn solid, or a link between two plain nodes drawn dotted.
test("dotted: a link to or from an external node", () => {
  const g = parse("external x\nskill s\na -> x, b, s\ns -> a");
  assert.deepEqual(g.edges.map(e => [e.source, e.target, !!e.dotted]), [["a", "x", true], ["a", "b", false], ["a", "s", true], ["s", "a", true]]);
});

test("a fill line gives its nodes a colour, and a bad colour warns", () => {
  const g = parse("fill #6B7158 a b\na -> b, c");
  const by = Object.fromEntries(g.nodes.map(n => [n.id, n]));
  assert.deepEqual([by.a.fill, by.b.fill, by.c.fill], ["#6B7158", "#6B7158", undefined]);
  const [, warn] = quiet(() => parse("fill red a"));
  assert.equal(warn.length, 1);
  assert.deepEqual(parse("fill -> b").edges.map(e => [e.source, e.target]), [["fill", "b"]]);
});

test("a direction line sets the first layout, and a bad one warns", () => {
  assert.equal(parse("direction right\na -> b").direction, "RIGHT");
  assert.equal(parse("a -> b").direction, undefined);
  const [, warn] = quiet(() => parse("direction up\na -> b"));
  assert.equal(warn.length, 1);
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

// graph-node-names: a node name has up to 6 words, its _ parts. A longer name draws and warns.
test("a node name of 1 to 6 words parses with no warning, each _ shown as a space", () => {
  const [g, warn] = quiet(() => parse("a -> six_words_in_one_node_name\nsix_words_in_one_node_name: a note"));
  assert.deepEqual(warn, [], "6 words is within the cap");
  assert.equal(g.nodes.find(n => n.id === "six_words_in_one_node_name").label, "six words in one node name");
});

test("a node name of 7 words still draws, and warns once with its name and word count", () => {
  const id = "seven_words_is_one_word_too_many";
  const [g, warn] = quiet(() => parse(`a -> ${id}\n${id}: a note\nexternal ${id}`));
  assert.ok(g.nodes.some(n => n.id === id), "the node is still in the graph");
  assert.equal(warn.length, 1, "one warning per name, not one per line that names it");
  assert.ok(warn[0].includes(id) && warn[0].includes("7 words"), warn[0]);
});

// graph-edge-labels F5: an about line gives each link with its text a note, one line per about line.
test("about lines give a link with that text a note, in order, and add no node", () => {
  const [g, warn] = quiet(() => parse("a -> b [food-record-body], c [other]\nabout [food-record-body]: 1. OCR\nabout [food-record-body]: 2. mark"));
  assert.deepEqual(g.edges.map(e => e.desc), ["1. OCR\n2. mark", undefined]);
  assert.deepEqual([g.nodes.length, warn], [3, []]);
});

// More description lines of one node join as lines of its hover, so a list shows as a list.
test("two description lines of one node join, one per line", () => {
  const [g] = quiet(() => parse("a -> b\na: One food.\na: - name"));
  assert.equal(g.nodes.find(n => n.id === "a").desc, "One food.\n- name");
});

// graph-filter: a filter line asks for the button row under the graph.
test("a filter line sets filter, and adds no node or link", () => {
  const [g, warn] = quiet(() => parse("filter\na -> b"));
  assert.equal(g.filter, true);
  assert.deepEqual([g.nodes.map(n => n.id), g.edges.length, warn], [["a", "b"], 1, []], "filter is no node");
});

test("a graph with no filter line has filter false", () => {
  assert.equal(parse("a -> b").filter, false);
});

test("a label line gives a node its display name, and two nodes can share one", () => {
  const [g, warn] = quiet(() => parse("label raw_recipe: recipe\nlabel staging_recipe: recipe\nraw_recipe -> staging_recipe\nlabel -> b"));
  const by = Object.fromEntries(g.nodes.map(n => [n.id, n]));
  assert.deepEqual([by.raw_recipe.label, by.staging_recipe.label, by.raw_recipe.name], ["recipe", "recipe", "recipe"]);
  assert.deepEqual([g.nodes.length, warn], [4, []], "no extra node, and a node named label still links");
});

// dotsGrow: in the center layout, a node with more links is a bigger dot.
test("dotSize: more links, bigger dot", () => {
  assert.ok(dotSize(3) > dotSize(1) && dotSize(0) > 0);
});
