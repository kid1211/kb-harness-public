/* draw-graph.js - draws a graph from short text, with an ELK layout, in Cytoscape.js.
 * Hover a node to light its links and neighbours and see its description; zoom, pan,
 * fit. Shared: any HTML page can load it. The text format is in the draw-graph skill.
 *
 *   <script src="https://cdn.jsdelivr.net/npm/cytoscape@3.34.3/dist/cytoscape.min.js"></script>
 *   <script src="https://cdn.jsdelivr.net/npm/elkjs@0.12.0/lib/elk.bundled.js"></script>
 *   <script src="draw-graph.js"></script>
 *   const cy = await DrawGraph.draw(div, text, { link: node => url or null, open: url => {}, direction: "DOWN" });
 *   DrawGraph.check(cy);   // the layout rules it breaks, one line each (check.js runs it on .md files)
 *
 * text may also be a graph that parse() returns. Top to bottom first; a button flips it.
 * The wheel scrolls the page; pinch or Ctrl+wheel zooms. Colours come from the --dg-*
 * CSS variables on the container or above it.
 */
(function () {
  "use strict";

  // Graph text -> { nodes, groups, edges }. Lines: "[Group] a b", "external a b", "a: description", "a -> b [label], c", "# comment".
  // A node on an "external" line is a component, not a step: it gets its own colour.
  // "begin a" marks where a flow starts, "end a b" where it ends well, and "fail a" where it stops on a failure.
  // "skill a" and "hook a" mark a component of that kind.
  // A node's ord is where a link line first names it; the layout keeps that order.
  function parse(txt) {
    const nodes = {}, groups = new Set(), edges = [], colorLines = [];
    let n = 0, direction, filter = false;
    const abouts = [];
    const MAX_WORDS = 6; // a name is up to 6 words, its _ parts (graph-node-names)
    const node = id => nodes[id] ??= (() => {
      const words = id.split("_").filter(Boolean).length;
      if (words > MAX_WORDS) console.warn(`draw-graph: node name ${id} has ${words} words, keep it to ${MAX_WORDS}`);
      return { id, label: id.replace(/_/g, " ") };
    })();
    for (const [i, raw] of txt.split("\n").entries()) {
      const l = raw.trim(); let m;
      if (!l || l.startsWith("#")) continue;
      if (l === "filter") filter = true; // a button row under the graph, to show or hide each node
      else if ((m = l.match(/^about\s+\[(.+?)\]:\s+(.+)$/))) abouts.push([m[1], m[2]]); // the note of each link with this text
      else if (/^color\s+(?!\s|->)/.test(l)) colorLines.push([l, i + 1]); // read after every node and link is known
      else if ((m = l.match(/^(external|begin|end|fail|skill|hook)\s+(?!->)(.+)$/))) m[2].split(/\s+/).forEach(id => {
        const k = m[1], nd = node(id);
        if (k === "external" || k === "skill" || k === "hook") nd.external = true;
        if (k !== "external") nd.kind = k;
      });
      else if ((m = l.match(/^ring\s+(\d+)\s+(.+)$/))) m[2].split(/\s+/).forEach(id => { node(id).ring = +m[1]; }); // "ring 0 a b": the center layout
      else if ((m = l.match(/^direction\s+(\S+)$/))) { // "direction right": the first layout is left to right
        if (/^(right|down)$/i.test(m[1])) direction = m[1].toUpperCase();
        else console.warn("draw-graph: direction is right or down", l);
      }
      else if ((m = l.match(/^fill\s+(?!->)(\S+)\s+(.+)$/))) { // "fill #hex a b": a colour of the nodes' own
        if (/^#[0-9a-fA-F]{6}$/.test(m[1])) m[2].split(/\s+/).forEach(id => { node(id).fill = m[1]; });
        else console.warn("draw-graph: fill needs a #rrggbb colour", l);
      }
      else if ((m = l.match(/^\[(.+?)\]\s*(.*)$/))) m[2].split(/\s+/).filter(Boolean).forEach(id => { node(id).parent = m[1]; groups.add(m[1]); });
      else if ((m = l.match(/^(\S+)\s*->\s*(.+)$/))) m[2].split(/,(?![^\[]*\])/).forEach(it => { // commas inside [label] do not split
        const [, b, label] = it.trim().match(/^(\S+)(?:\s*\[(.+)\])?$/) || [];
        if (!b) return console.warn("draw-graph: bad target", it);
        node(m[1]).ord ??= n++; node(b).ord ??= n++;
        edges.push({ source: m[1], target: b, label });
      });
      else if ((m = l.match(/^label\s+(\S+):\s+(.+)$/))) Object.assign(node(m[1]), { label: m[2], name: m[2] }); // a display name apart from the ID
      else if ((m = l.match(/^(\S+?)\.run:\s*(.+)$/))) node(m[1]).run = m[2];
      else if ((m = l.match(/^(\S+):\s+(.+)$/))) { const o = node(m[1]); o.desc = o.desc ? o.desc + "\n" + m[2] : m[2]; } // an ID may hold a colon, as p-req:grill. Each more line adds a line
      else console.warn("draw-graph: unread line", l);
    }
    for (const [l, at] of colorLines) applyColors(l, at, nodes, edges);
    // A state box (R26): its name, a rule, the component that runs it, then the components of the nodes
    // its links come in from and go out to: a node's run, or its name if it has none. What it does stays in the hover.
    const comps = id => nodes[id].run ? nodes[id].run.split(/,\s*/) : [id.replace(/_/g, " ").replace(/\?$/, "")];
    const ends = (id, from, to) => [...new Set(edges.filter(e => e[from] === id && e.source !== e.target).flatMap(e => comps(e[to])))].join(", ");
    const labels = Object.fromEntries(Object.values(nodes).filter(n => n.run).map(n => {
      const i = ends(n.id, "target", "source"), o = ends(n.id, "source", "target");
      // An icon sits on the name line, in the room the spaces leave.
      return [n.id, [(n.kind ? "\u2800".repeat(2) + " " : "") + n.label, "----", `run: [${n.run}]`, i && `in: [${i}]`, o && `out: [${o}]`].filter(Boolean).join("\n")];
    }));
    for (const [id, label] of Object.entries(labels)) Object.assign(nodes[id], { label, state: true });
    for (const e of edges) { const d = abouts.filter(a => a[0] === e.label).map(a => a[1]); if (d.length) e.desc = d.join("\n"); }
    // A link to or from an external node, such as a component, a skill or a hook, is dotted.
    for (const e of edges) if (nodes[e.source]?.external || nodes[e.target]?.external) e.dotted = true;
    return { nodes: Object.values(nodes), groups: [...groups], edges, direction, filter };
  }

  // A colour line: "color a text=tan fill=midnight" for a node, "color a -> b line=tan label=linen" for each link a to b.
  // Palette names only (.claude/lib/palette/palette.css). Dark colours are fills only. Firebrick is for errors only.
  const LIGHT = { tan: "#D2B48C", linen: "#FAF0E6", "light-blue": "#A8D8EA", white: "#FFFFFF" };
  const LINE = { ...LIGHT, "slate-blue": "#4A6A88" };
  const FILL = { ...LINE, navy: "#001F3F", midnight: "#191970", charcoal: "#363636", olive: "#6B7158", fern: "#4F7942" };
  const PARTS = { node: { text: LIGHT, fill: FILL }, link: { line: LINE, label: LIGHT } };
  function applyColors(l, at, nodes, edges) {
    const bad = why => { throw new Error(`draw-graph: ${why}, in line ${at} "${l}"`); };
    const own = (o, k) => Object.hasOwn(o, k) ? o[k] : undefined; // no inherited names, such as toString
    const m = l.match(/^color\s+(\S+)(?:\s*->\s*(\S+))?((?:\s+\S+=\S+)+)$/) || bad("write color <node> text=<name> fill=<name>, or color <a> -> <b> line=<name> label=<name>");
    const [, a, b, pairs] = m, kind = b ? "link" : "node";
    if (a === b) bad("a loop takes no colour");
    const targets = b ? edges.filter(e => e.source === a && e.target === b) : own(nodes, a) ? [nodes[a]] : [];
    if (!targets.length) bad(b ? `no link ${a} -> ${b}` : `no node ${a}`);
    const colors = {};
    for (const p of pairs.trim().split(/\s+/)) {
      const [key, name, ...rest] = p.split("=");
      if (rest.length) bad(`${name}=${rest.join("=")} is no palette colour`);
      const fit = own(PARTS[kind], key) || bad(`a ${kind} has no part ${key}: use ${Object.keys(PARTS[kind]).join(" or ")}`);
      colors[key] = own(fit, name) || bad(own(FILL, name) ? `${name} is a fill colour, too dark for ${key}: use ${Object.keys(fit).join(", ")}`
        : `${name} is no palette colour for ${key}: use ${Object.keys(fit).join(", ")}`);
    }
    for (const t of targets) t.colors = { ...t.colors, ...colors };
  }

  // { text, fill } -> { c_text, c_fill }: plain data fields, so a style selector can read them.
  const flat = c => Object.fromEntries(Object.entries(c || {}).map(([k, v]) => ["c_" + k, v]));

  const STYLE = `
.dg { position: relative; width: 100%; }
.dg-flip { position: absolute; top: 6px; right: 6px; z-index: 5; font: 13px/1 system-ui, sans-serif; cursor: pointer;
  padding: 4px 8px; border-radius: 5px; border: 1px solid var(--dg-group, #bbb); background: var(--dg-bg, #fff); color: var(--dg-fg, #1d1d1b); }
.dg-reset { right: 104px; }
.dg-filter { display: flex; flex-wrap: wrap; justify-content: center; gap: 10px 12px; padding: 16px 12%; }
.dg-filter button { white-space: nowrap; font: inherit; line-height: 1.3; cursor: pointer; padding: 6px 14px;
  border-radius: 5px; border: 1px solid var(--dg-group, #bbb); background: var(--dg-bg, #fff); color: var(--dg-fg, #1d1d1b); }
.dg-filter button.off { opacity: 0.35; }
.dg-filter .dg-all { font-weight: 600; }
.dg-tip { position: fixed; z-index: 10; max-width: 320px; padding: 6px 9px; border-radius: 5px; font-size: 13px;
  line-height: 1.4; pointer-events: none; display: none; background: #222; color: #fff; white-space: pre-line; }`;
  // One text size for nodes and links: the page's own, set in draw(). 13 px until then.
  // ponytail: one size for the whole page, which holds for the Markdown preview. Keep it per graph if boxes ever differ.
  const FONT = { node: 13, edge: 13 };
  // A graph never shrinks below its real size, so its text matches the page. A bigger graph pans instead.
  const MIN_ZOOM = 1;
  // Line icons in the style of Lucide (ISC licence): one stroke colour, no fill, so they read on a dark theme.
  const ICON = {
    // The user's picks, 2026-10-23: power on, flag, circled cross, box, plug.
    begin: '<path d="M12 2v10"/><path d="M18.4 6.6a9 9 0 1 1-12.77.04"/>',
    end: '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/>',
    fail: '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>',
    skill: '<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
    hook: '<path d="M12 22v-5"/><path d="M9 8V2"/><path d="M15 8V2"/><path d="M18 8v5a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4V8Z"/>' };
  const iconUrl = (kind, colour) => "data:image/svg+xml;utf8," + encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="${colour}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">${ICON[kind]}</svg>`);
  const ctx = typeof document !== "undefined" && document.createElement("canvas").getContext("2d");
  // The widest line, since a state box has several (R26).
  const textWidth = t => { ctx.font = `${FONT.node}px "Helvetica Neue", Helvetica, sans-serif`; return Math.max(...t.split("\n").map(l => ctx.measureText(l).width)); };
  // A state box wraps at WRAP px: the width of its widest line after the wrap, word by word, as Cytoscape does.
  const WRAP = 280;
  const wrapLines = (t, max) => t.split("\n").flatMap(l => l.split(" ").reduce((ls, w) => {
    const cur = ls[ls.length - 1], next = cur ? cur + " " + w : w;
    if (cur && textWidth(next) > max) ls.push(w); else ls[ls.length - 1] = next;
    return ls; }, [""]));
  const wrapWidth = t => Math.max(...wrapLines(t, WRAP).map(textWidth));
  // A link's text wraps at the width of "get-grocery-list", and sits in the line.
  const edgeWrap = () => textWidth("get-grocery-list");
  const EDGE_PAD = 3, EDGE_LINE = 1.2;
  const edgeLabelSize = t => { const ls = wrapLines(t, edgeWrap());
    return { width: Math.max(...ls.map(textWidth)) + 2 * EDGE_PAD, height: ls.length * FONT.edge * EDGE_LINE + 2 * EDGE_PAD }; };
  // A plain node wraps its name at the width of this text, so a long name takes two lines, not a wide box.
  const NAME_WRAP_TEXT = "raw recipe source";
  const groupW = n => n.data("label").length * FONT.node * 0.6; // about the width of a group's name

  // The center layout (graph-center-layout). Each node goes on its ring around (0, 0): ring 0 in the middle, a node
  // with no ring on the ring after the last. Inside a ring, more links pull a node in, by up to PULL, less than STEP,
  // so the rings keep their order. A node sits near the mean angle of its links, and the nodes of a ring spread so
  // no two touch. nodes: [{ id, ring, w, h }], edges: [[source, target]]. Returns { id: { x, y } }.
  const RING = { STEP: 250, PULL: 90, GAP: 110, LINK: 30, OUTER: 0.7 };
  // In the center layout each node is a dot, bigger with more links.
  const dotSize = links => 12 + 3 * links;
  function ringPlace(nodes, edges, scale = 1) {
    const S = { STEP: RING.STEP * scale, PULL: RING.PULL * scale, GAP: RING.GAP * scale, LINK: RING.LINK * scale };
    const levels = [...new Set(nodes.map(n => n.ring).filter(r => r != null))].sort((a, b) => a - b);
    const k = n => n.ring == null ? levels.length : levels.indexOf(n.ring);
    const deg = Object.fromEntries(nodes.map(n => [n.id, 0])), nb = Object.fromEntries(nodes.map(n => [n.id, new Set()]));
    for (const [s, d] of edges) if (s in deg && d in deg && s !== d) { deg[s]++; deg[d]++; nb[s].add(d); nb[d].add(s); }
    const most = Math.max(1, ...Object.values(deg));
    const rings = [];
    for (const n of nodes) (rings[k(n)] ??= []).push(n);
    const at = new Map(rings.flatMap((ns, i) => (ns || []).map(n => [n.id, i])));
    // The base radius of each ring: STEP past the one inside it, and wide enough to hold its nodes side by side.
    const base = [];
    rings.forEach((ns, i) => {
      const need = (ns || []).reduce((s, n) => s + n.w + S.GAP + S.LINK * deg[n.id], 0) / (2 * Math.PI);
      // A ring past the first holds few links, so it sits closer: OUTER of the step.
      base[i] = i === 0 && (ns || []).length === 1 ? 0 : Math.max(i ? base[i - 1] + S.STEP * RING.OUTER : 0, need);
    });
    const rad = n => base[at.get(n.id)] + (base[at.get(n.id)] || at.get(n.id) ? S.PULL * (1 - deg[n.id] / most) : 0);
    const ang = {};
    const mean = id => { let x = 0, y = 0, c = 0;
      for (const o of nb[id]) if (ang[o] != null) { x += Math.cos(ang[o]); y += Math.sin(ang[o]); c++; }
      return c && Math.hypot(x, y) > 1e-6 ? Math.atan2(y, x) : null; };
    // First angles, ring by ring from the middle: the most linked first, then each by the nodes it links to.
    rings.forEach(ns => {
      (ns || []).slice().sort((a, b) => deg[b.id] - deg[a.id]).forEach((n, i, all) => {
        ang[n.id] = mean(n.id) ?? (2 * Math.PI * i / all.length + 0.3 * at.get(n.id)); });
    });
    // Spread one ring: each node stays as near its wanted angle as it can, and neighbours move apart only as far
    // as their width needs. A ring too full for that shares the whole circle, in the order of the wanted angles.
    const spread = (ns, r) => {
      if (!ns || ns.length < 2 || !r) return;
      const s = ns.slice().sort((a, b) => ang[a.id] - ang[b.id]), T = 2 * Math.PI;
      const need = s.map(n => (n.w + S.GAP + S.LINK * deg[n.id]) / r), total = need.reduce((x, y) => x + y, 0);
      if (total < T) {
        const a = s.map(n => ang[n.id]);
        for (let it = 0; it < 200; it++) {
          let moved = false;
          for (let i = 0; i < s.length; i++) {
            const j = (i + 1) % s.length, g = (need[i] + need[j]) / 2, d = ((a[j] - a[i]) % T + T) % T;
            if (d < g - 1e-9) { const push = (g - d) / 2; a[i] -= push; a[j] += push; moved = true; }
          }
          if (!moved) break;
        }
        s.forEach((n, i) => { ang[n.id] = a[i]; });
        return;
      }
      const share = need, off = [];
      let c = 0;
      s.forEach((n, i) => { off[i] = c + share[i] / 2; c += share[i]; });
      let x = 0, y = 0;
      s.forEach((n, i) => { x += Math.cos(ang[n.id] - off[i]); y += Math.sin(ang[n.id] - off[i]); });
      const turn = Math.atan2(y, x);
      s.forEach((n, i) => { ang[n.id] = turn + off[i]; });
    };
    for (let sweep = 0; sweep < 8; sweep++) rings.forEach((ns, i) => {
      if (sweep) (ns || []).forEach(n => { const m = mean(n.id); if (m != null) ang[n.id] = m; });
      spread(ns, base[i] || S.STEP);
    });
    const pos = {};
    for (const n of nodes) { const r = rad(n); pos[n.id] = { x: r * Math.cos(ang[n.id]), y: r * Math.sin(ang[n.id]) }; }
    // A node that still touches another moves out along its ray, a little at a time.
    for (let it = 0; it < 100; it++) {
      let moved = false;
      for (const a of nodes) for (const b of nodes) {
        if (a.id >= b.id) continue;
        const pa = pos[a.id], pb = pos[b.id];
        if (Math.abs(pa.x - pb.x) >= (a.w + b.w) / 2 + 4 || Math.abs(pa.y - pb.y) >= (a.h + b.h) / 2 + 4) continue;
        const o = Math.hypot(pa.x, pa.y) >= Math.hypot(pb.x, pb.y) ? pa : pb, l = Math.hypot(o.x, o.y) || 1;
        o.x += o.x / l * 12; o.y += o.y / l * 12; moved = true;
      }
      if (!moved) break;
    }
    return pos;
  }

  // Draw a graph with ring lines by ringPlace: straight links, each bent round a node it would cross, and each text
  // at the first point of its line where it covers no node and no other text.
  function centerLayout(cy, g, box) {
    const ns = cy.nodes(":childless");
    const pos = ringPlace(ns.map(n => { const b = n.boundingBox(); return { id: n.id(), ring: n.data("ring"), w: b.w, h: b.h }; }),
      cy.edges().map(e => [e.source().id(), e.target().id()]));
    ns.positions(n => pos[n.id()]);
    const boxes = ns.map(n => { const b = n.boundingBox(); return { id: n.id(), x1: b.x1 - 4, x2: b.x2 + 4, y1: b.y1 - 4, y2: b.y2 + 4 }; });
    const hit = (a, b) => a.x1 < b.x2 && b.x1 < a.x2 && a.y1 < b.y2 && b.y1 < a.y2;
    const curve = (s, t, d) => { const mx = (s.x + t.x) / 2, my = (s.y + t.y) / 2, l = Math.hypot(t.x - s.x, t.y - s.y) || 1;
      const c = { x: mx - (t.y - s.y) / l * 2 * d, y: my + (t.x - s.x) / l * 2 * d };
      return u => ({ x: (1 - u) ** 2 * s.x + 2 * u * (1 - u) * c.x + u * u * t.x, y: (1 - u) ** 2 * s.y + 2 * u * (1 - u) * c.y + u * u * t.y }); };
    const crosses = (at, e) => { for (let u = 0.02; u < 0.985; u += 0.005) { const q = at(u);
      if (boxes.some(b => b.id !== e.source().id() && b.id !== e.target().id() && q.x > b.x1 && q.x < b.x2 && q.y > b.y1 && q.y < b.y2)) return true; }
      return false; };
    // Each link: the bends to try. Two links between one pair, as a round trip, bend to each side so they stay apart.
    const bends = e => e.parallelEdges().length > 1 ? [45, 90, 140, 200, 270, -60, -120, -200] : [0, 40, -40, 80, -80, 120, -120, 170, -170, 230, -230, 300, -300];
    const sample = at => { const pts = []; for (let u = 0; u <= 1.0001; u += 0.01) pts.push(at(u)); return pts; };
    // Cytoscape's control point is twice as far off as the curve's middle.
    const bend = (e, d) => d ? e.style({ "curve-style": "unbundled-bezier", "edge-distances": "node-position", "control-point-distances": [2 * d], "control-point-weights": [0.5] })
      : e.style({ "curve-style": "straight" });
    // Place the lines and texts with the links in this order. Returns the links whose text found no free spot.
    const texts = [], inside = (q, b) => q.x > b.x1 && q.x < b.x2 && q.y > b.y1 && q.y < b.y2;
    const us = [0.5]; for (let i = 1; i <= 10; i++) us.push(0.5 - i * 0.037, 0.5 + i * 0.037);
    const paths = new Map();
    const place = order => {
      texts.length = 0; paths.clear();
      // First the line of each link, bent round each node it would cross.
      order.forEach(e => {
        const s = e.source().position(), t = e.target().position();
        let d = 0, at = curve(s, t, 0);
        for (const c of bends(e)) { const f = curve(s, t, c); if (!crosses(f, e)) { d = c; at = f; break; } }
        paths.set(e.id(), { e, d, at, pts: sample(at) });
      });
      // Then each text, at the first point that covers no node, no other text and no other line. If its line has
      // no such point, the line takes another bend that crosses no node and no text placed so far.
      const failed = [];
      order.forEach(e => {
        const label = e.data("label");
        if (!label) return;
        const s = e.source().position(), t = e.target().position(), sz = edgeLabelSize(label);
        const boxAt = q => ({ x1: q.x - sz.width / 2 - 4, x2: q.x + sz.width / 2 + 4, y1: q.y - sz.height / 2 - 4, y2: q.y + sz.height / 2 + 4 });
        const free = b => !boxes.some(x => hit(x, b)) && !texts.some(x => hit(x, b)) &&
          ![...paths].some(([id, p]) => id !== e.id() && p.pts.some(q => inside(q, b)));
        const own = paths.get(e.id());
        let pick = null;
        for (const d of [null, ...bends(e)]) {
          const at = d == null ? own.at : curve(s, t, d), pts = d == null ? own.pts : sample(at);
          if (d != null && (crosses(at, e) || pts.some(q => texts.some(b => inside(q, b))))) continue;
          const u = us.find(u => free(boxAt(at(u))));
          if (u != null) { pick = { d: d ?? own.d, at, pts, q: at(u) }; break; }
        }
        if (!pick) { failed.push(e); pick = { d: own.d, at: own.at, pts: own.pts, q: own.at(0.5) }; }
        paths.set(e.id(), { e, d: pick.d, at: pick.at, pts: pick.pts, q: pick.q });
        texts.push(boxAt(pick.q));
      });
      return failed;
    };
    // A link whose text found no spot goes first in the next try, up to 6 tries.
    let order = cy.edges().toArray();
    for (let i = 0; i < 6; i++) {
      const failed = place(order);
      if (!failed.length) break;
      order = [...failed, ...order.filter(e => !failed.includes(e))];
    }
    for (const { e, d, q } of paths.values()) {
      bend(e, d);
      if (!q) continue;
      const m = e.midpoint();
      e.style({ "text-margin-x": q.x - m.x, "text-margin-y": q.y - m.y });
      // Where Cytoscape really put the text: move it the rest of the way to q.
      const lb = e.boundingBox({ includeEdges: false, includeLabels: true });
      if (lb.w) e.style({ "text-margin-x": q.x - m.x + q.x - (lb.x1 + lb.x2) / 2, "text-margin-y": q.y - m.y + q.y - (lb.y1 + lb.y2) / 2 });
    }
    const bb = cy.elements().boundingBox();
    const z = Math.max(MIN_ZOOM, Math.min(1.2, (box.clientWidth - 40) / bb.w));
    box.style.height = Math.max(140, Math.min(bb.h * z + 60, innerHeight * 0.9)) + "px";
    cy.resize();
    cy.fit(undefined, 30);
    cy.scratch("fitZoom", cy.zoom());
    if (cy.zoom() > 1.2) { cy.zoom(1.2); cy.center(); }
    else if (cy.zoom() < MIN_ZOOM) { const b = cy.elements().boundingBox(); cy.zoom(MIN_ZOOM); cy.pan({ x: 30 - b.x1 * MIN_ZOOM, y: 30 - b.y1 * MIN_ZOOM }); }
  }

  // Lay the graph out with ELK in one direction, "DOWN" or "RIGHT", and draw it at those positions.
  async function layout(cy, g, box, dir) {
    cy.remove(".loopnote");
    cy.edges().removeStyle();
    if (g.nodes.some(n => n.ring != null)) return centerLayout(cy, g, box); // ring lines: the center layout
    const byOrd = (a, b) => a.ord - b.ord;
    const kids = p => cy.nodes(":childless").filter(n => (n.data("parent") || null) === p)
      .map(n => ({ id: n.id(), width: n.outerWidth(), height: n.outerHeight(), ord: n.data("ord") ?? Infinity })).sort(byOrd);
    const boxes = g.groups.map(id => { const children = kids(id);
      return { id, children, ord: Math.min(...children.map(c => c.ord)), layoutOptions: { "elk.padding": "[top=30,left=12,bottom=12,right=12]" } }; });
    const res = await new ELK().layout({
      id: "root",
      layoutOptions: { "elk.algorithm": "layered", "elk.direction": dir, "elk.hierarchyHandling": "INCLUDE_CHILDREN",
        "elk.layered.spacing.nodeNodeBetweenLayers": "40", "elk.spacing.nodeNode": "24",
        // Bend points and labels in page coordinates, even in a group. A link back against the order is drawn as a loop.
        "elk.json.edgeCoords": "ROOT", "elk.layered.cycleBreaking.strategy": "MODEL_ORDER" },
      children: [...boxes, ...kids(null)].sort(byOrd),
      // Label sizes make ELK leave room for the text.
      // A loop inside a node (R27) is left to Cytoscape, which draws it on the node's side.
      edges: g.edges.map((e, i) => ({ id: "e" + i, sources: [e.source], targets: [e.target],
        labels: e.label ? [{ text: e.label, ...edgeLabelSize(e.label), layoutOptions: { "elk.edgeLabels.inline": "true" } }] : [] }))
        .filter(e => e.sources[0] !== e.targets[0]),
    });
    const pos = {};
    const place = (ns, ox, oy) => ns.forEach(n => {
      const x = ox + n.x, y = oy + n.y;
      if (n.children?.length) place(n.children, x, y); else pos[n.id] = { x: x + n.width / 2, y: y + n.height / 2 };
    });
    place(res.children, 0, 0);
    // The box is as tall as the graph at the width it gets, up to 90% of the window (R28): a taller graph pans inside the box.
    const z = Math.max(MIN_ZOOM, Math.min(1.2, (box.clientWidth - 40) / res.width));
    box.style.height = Math.max(140, Math.min(res.height * z + 60, innerHeight * 0.9)) + "px";
    cy.resize();
    cy.nodes(":childless").positions(n => pos[n.id()]);
    // Each link follows ELK's route exactly: its end points on the node borders, as offsets from the
    // node centres, and its bend points as Cytoscape segments (weight along the centre line, distance off it).
    for (const e of res.edges) {
      // A link with several sections is joined into one route.
      const secs = e.sections || [], edge = cy.getElementById(e.id);
      if (!secs.length) continue;
      const sec = { startPoint: secs[0].startPoint, endPoint: secs[secs.length - 1].endPoint,
        bendPoints: secs.flatMap((x, i) => [...(x.bendPoints || []), ...(i < secs.length - 1 ? [x.endPoint] : [])]) };
      if (!sec.bendPoints.length) delete sec.bendPoints;
      const s = edge.source().position(), t = edge.target().position();
      // A decision is a diamond: slide each end point from its box border in along the line, onto the diamond.
      const off = (p, c, n) => {
        let x = p.x - c.x, y = p.y - c.y;
        if (n.hasClass("decision")) {
          const w = n.outerWidth() / 2, h = n.outerHeight() / 2;
          if (Math.abs(y) >= h - 0.5) y = Math.sign(y) * h * Math.max(0, 1 - Math.abs(x) / w);
          else x = Math.sign(x) * w * Math.max(0, 1 - Math.abs(y) / h);
        }
        return `${x}px ${y}px`;
      };
      edge.style({ "source-endpoint": off(sec.startPoint, s, edge.source()), "target-endpoint": off(sec.endPoint, t, edge.target()) });
      const pts = sec.bendPoints;
      if (pts) {
        const dx = t.x - s.x, dy = t.y - s.y, l2 = dx * dx + dy * dy || 1;
        edge.style({ "curve-style": "round-segments", "segment-radius": 8, "edge-distances": "node-position",
          "segment-weights": pts.map(p => ((p.x - s.x) * dx + (p.y - s.y) * dy) / l2),
          "segment-distances": pts.map(p => (dx * (p.y - s.y) - dy * (p.x - s.x)) / Math.sqrt(l2)) });
      }
      // The label goes where ELK left room for it, moved onto the nearest point of the line, so it sits in it.
      const l = e.labels?.[0];
      if (l && l.x != null) {
        const c = { x: l.x + l.width / 2, y: l.y + l.height / 2 }, route = [sec.startPoint, ...(pts || []), sec.endPoint];
        const on = route.slice(1).map((q, i) => { const p = route[i], dx = q.x - p.x, dy = q.y - p.y;
          const k = Math.max(0, Math.min(1, ((c.x - p.x) * dx + (c.y - p.y) * dy) / (dx * dx + dy * dy || 1)));
          return { x: p.x + k * dx, y: p.y + k * dy }; })
          .reduce((a, b) => Math.hypot(a.x - c.x, a.y - c.y) <= Math.hypot(b.x - c.x, b.y - c.y) ? a : b);
        const m = edge.midpoint();
        edge.style({ "text-margin-x": on.x - m.x, "text-margin-y": on.y - m.y }); }
    }
    // A loop inside a node (R27): a link out of its right side to its text, and one back in, below it.
    // Cytoscape cannot draw a loop next to links laid out by ELK, so the text is a small node of its own.
    for (const e of g.edges.filter(e => e.source === e.target)) {
      const n = cy.getElementById(e.source), p = n.position(), w = n.outerWidth() / 2, h = Math.min(16, n.outerHeight() / 4);
      const id = e.source + "__loop", label = e.label || "", tw = textWidth(label) / 2 + 4;
      cy.add([{ data: { id, label }, classes: "loopnote", position: { x: p.x + w + 40 + tw, y: p.y } },
        { data: { id: id + "_out", source: e.source, target: id }, classes: "loop" },
        { data: { id: id + "_in", source: id, target: e.source }, classes: "loop" }]);
      cy.getElementById(id + "_out").style({ "source-endpoint": `${w}px ${-h}px`, "target-endpoint": `${-tw}px 0px`, "target-arrow-shape": "none" });
      cy.getElementById(id + "_in").style({ "source-endpoint": `${-tw}px 0px`, "target-endpoint": `${w}px ${h}px` });
      if (n.style("display") === "none") cy.getElementById(id).style("display", "none"); // a filtered node keeps its loop text hidden
    }
    // A group's name sits at its top left corner, where fewer links come in than at the middle.
    cy.nodes(":parent").forEach(n => n.style("text-margin-x", 10 + groupW(n) / 2 - n.width() / 2));
    cy.fit(undefined, 30);
    cy.scratch("fitZoom", cy.zoom()); // the zoom that shows it all, for the density check
    if (cy.zoom() > 1.2) { cy.zoom(1.2); cy.center(); } // a small graph is not blown up
    else if (cy.zoom() < MIN_ZOOM) { // too big to read whole: keep the text readable, show the start, and pan for the rest
      const bb = cy.elements().boundingBox();
      cy.zoom(MIN_ZOOM); cy.pan({ x: 30 - bb.x1 * MIN_ZOOM, y: 30 - bb.y1 * MIN_ZOOM });
    }
  }

  async function draw(box, src, opts = {}) {
    if (!document.getElementById("dg-style")) document.head.append(Object.assign(document.createElement("style"), { id: "dg-style", textContent: STYLE }));
    const g = typeof src === "string" ? parse(src) : src;
    FONT.node = FONT.edge = Math.round(parseFloat(getComputedStyle(box).fontSize)) || 13;
    const css = getComputedStyle(box), v = (k, d) => css.getPropertyValue(k).trim() || d;
    const C = { node: v("--dg-node", "#eef"), fg: v("--dg-fg", "#1d1d1b"), border: v("--dg-border", "#334"),
      line: v("--dg-line", "#888"), hl: v("--dg-hl", "#e33"), bg: v("--dg-bg", "#fff"), group: v("--dg-group", "#bbb"), comp: v("--dg-comp", "#dde"),
      begin: v("--dg-begin", "#c8d8ea"), end: v("--dg-end", "#cfe8c8"), fail: v("--dg-fail", "#f2c8c8"), skill: v("--dg-skill", "#36c"), hook: v("--dg-hook", "#a73") };
    box.classList.add("dg");
    const urls = {};
    for (const n of g.nodes) { const u = opts.link && opts.link(n); if (u) urls[n.id] = u; }
    const dots = g.nodes.some(n => n.ring != null);
    const cy = cytoscape({
      container: box, userZoomingEnabled: false, // the wheel scrolls the page; pinch or Ctrl+wheel zooms (below)
      elements: [...g.groups.map(id => ({ data: { id, label: id.replace(/_/g, " ") } })),
        ...g.nodes.map(n => ({ data: { ...n, ...flat(n.colors) }, classes: (dots ? ["dot", urls[n.id] && "link", n.external && "external"] : [urls[n.id] && "link", n.external && "external", n.state && "state", n.id.endsWith("?") && "decision", ["begin", "end", "fail"].includes(n.kind) ? "terminal " + n.kind : n.kind, n.kind && "icon"]).filter(Boolean).join(" ") })),
        // In the center layout a link keeps its text as tip, shown only on hover.
        ...g.edges.map((e, i) => { const { label, ...rest } = e; return { data: { ...(dots ? { ...rest, tip: label } : e), ...flat(e.colors), id: "e" + i }, classes: e.dotted ? "dotted" : "" }; }).filter(e => e.data.source !== e.data.target)],
      layout: { name: "preset" },
      style: [
        { selector: "node", style: { label: "data(label)", shape: "round-rectangle", width: "label", height: 26, padding: 7,
          "text-valign": "center", "font-size": FONT.node, color: C.fg, "background-color": C.node, "border-width": 1, "border-color": C.border } },
        { selector: "node:childless[^state][^kind]", style: { "text-wrap": "wrap", "text-max-width": () => textWidth(NAME_WRAP_TEXT) + 1,
          height: n => 26 + (wrapLines(n.data("label"), textWidth(NAME_WRAP_TEXT) + 1).length - 1) * Math.round(FONT.node * 1.25) } },
        { selector: "node.external", style: { "background-color": C.comp } },
        { selector: "node[fill]", style: { "background-color": "data(fill)" } },
        { selector: "node.state", style: {
          "text-wrap": "wrap", "text-max-width": WRAP, "text-justification": "left", height: "label", "line-height": 1.35 } },
        { selector: "node.decision", style: { shape: "diamond", height: 44, padding: 22 } },
        // A flow's start and end are pills, as in a flowchart.
        { selector: "node.terminal", style: { "corner-radius": 13, padding: 12 } },
        { selector: "node.begin", style: { "background-color": C.begin } },
        { selector: "node.end", style: { "background-color": C.end } },
        { selector: "node.fail", style: { "background-color": C.fail } },
        // A skill and a hook are components with a border of their own colour.
        { selector: "node.skill", style: { "border-width": 2, "border-color": C.skill } },
        { selector: "node.hook", style: { "border-width": 2, "border-color": C.hook } },
        // A node with a kind has its icon at the left, and its text moves right to make room. A state box has it beside its name.
        { selector: "node.icon", style: { width: n => n.hasClass("state") ? wrapWidth(n.data("label")) : textWidth(n.data("label")) + 18, "text-margin-x": n => n.hasClass("state") ? 0 : 9,
          "background-image": n => iconUrl(n.data("kind"), { skill: C.skill, hook: C.hook }[n.data("kind")] || C.fg),
          "background-width": 13, "background-height": 13, "background-position-x": n => n.hasClass("terminal") ? 12 : 7,
          "background-position-y": n => n.hasClass("state") ? 9 : "50%", "background-clip": "none", "background-image-containment": "over" } },
        { selector: "node.link", style: { "border-width": 2, "text-decoration": "underline" } },
        { selector: ":parent", style: { "text-valign": "top", "background-opacity": .06, "border-color": C.group, "border-style": "dashed" } },
        // Straight until ELK has placed the nodes. Then each link follows ELK's route (layout).
        { selector: "edge", style: { "curve-style": "straight", "target-arrow-shape": "triangle", width: 1.2,
          "line-color": C.line, "target-arrow-color": C.line } },
        { selector: "edge.dotted", style: { "line-style": "dotted" } },
        { selector: "edge[label]", style: { label: "data(label)", "text-events": "yes", "font-size": FONT.edge, color: C.fg, "text-rotation": "none",
          "text-wrap": "wrap", "text-max-width": edgeWrap(), "line-height": EDGE_LINE,
          // The page background behind the text hides the link there, so the line looks broken.
          "text-background-color": C.bg, "text-background-opacity": 1, "text-background-padding": EDGE_PAD } },
        // A loop inside a node (R27) curls out of its right side, with its text beyond the curl.
        { selector: "node.loopnote", style: { "background-opacity": 0, "border-width": 0, "font-size": FONT.edge, width: "label", height: "label", padding: 2 } },
        // A colour line wins over the colour of a node's or link's kind. The hover still dims and lights it.
        { selector: "node[c_text]", style: { color: "data(c_text)" } },
        { selector: "node[c_fill]", style: { "background-color": "data(c_fill)" } },
        { selector: "edge[c_line]", style: { "line-color": "data(c_line)", "target-arrow-color": "data(c_line)" } },
        { selector: "edge[c_label]", style: { color: "data(c_label)" } },
        // A dot, like Obsidian's graph view: its name under it, in the text colour of its node.
        { selector: "node.dot", style: { shape: "ellipse", width: n => dotSize(n.degree()), height: n => dotSize(n.degree()), padding: 0,
          "text-valign": "bottom", "text-margin-y": 4, "background-color": C.fg, "border-width": 0, "text-wrap": "none" } },
        { selector: "node.dot.external", style: { "background-color": C.line, color: C.line } },
        { selector: "node.dot[c_text]", style: { "background-color": "data(c_text)" } },
        { selector: "edge.hl[tip]", style: { label: "data(tip)", "font-size": FONT.edge, color: C.fg, "text-rotation": "none",
          "text-background-color": C.bg, "text-background-opacity": 1, "text-background-padding": EDGE_PAD } },
        { selector: ".dim", style: { opacity: .15 } },
        { selector: "edge.hl", style: { "line-color": C.hl, "target-arrow-color": C.hl, width: 2.5 } },
      ],
    });

    // Top to bottom first; the button flips it to left to right and back.
    let dir = opts.direction || g.direction || "DOWN";
    await layout(cy, g, box, dir);
    const flip = Object.assign(document.createElement("button"), { className: "dg-flip", type: "button" });
    const label = () => { flip.textContent = "⇄ transpose"; flip.title = dir === "DOWN" ? "Show left to right" : "Show top to bottom"; };
    label();
    flip.onclick = async () => { dir = dir === "DOWN" ? "RIGHT" : "DOWN"; label(); await layout(cy, g, box, dir); };
    // Reset: the graph as it was first drawn, in its first direction, with no node moved.
    const first = dir;
    const reset = Object.assign(document.createElement("button"), { className: "dg-flip dg-reset", type: "button",
      textContent: "↺ reset", title: "Show the graph as it was first drawn" });
    reset.onclick = async () => { dir = first; label(); await layout(cy, g, box, dir); };
    box.append(flip, reset);
    // A filter line: one button per node under the graph. A click hides or shows the node; Cytoscape hides its links.
    if (g.filter) {
      if (box.nextElementSibling && box.nextElementSibling.classList.contains("dg-filter")) box.nextElementSibling.remove();
      const row = Object.assign(document.createElement("div"), { className: "dg-filter" });
      // The buttons use the size and font of the node text, as drawn.
      row.style.font = `${Math.round(FONT.node * Math.max(1, cy.zoom()))}px "Helvetica Neue", Helvetica, sans-serif`;
      const fit = () => { const on = cy.nodes(":visible"); if (on.length) cy.fit(on, 20); };
      const btns = [];
      // A button selects or clears its node. The graph shows the selected nodes.
      const apply = () => {
        const shown = new Set(btns.filter(b => !b.classList.contains("off")).map(b => b.dataset.id));
        btns.forEach(b => cy.$id(b.dataset.id).union(cy.$id(b.dataset.id + "__loop")).style("display", shown.has(b.dataset.id) ? "element" : "none"));
      };
      const set = (b, on) => { b.classList.toggle("off", !on); apply(); };
      const mk = (text, cls, onclick) => { const b = Object.assign(document.createElement("button"), { type: "button", textContent: text, className: cls });
        b.onclick = onclick; row.append(b); return b; };
      mk("All", "dg-all", () => { btns.forEach(b => set(b, true)); fit(); });
      mk("None", "dg-all", () => btns.forEach(b => set(b, false)));
      for (const n of [...g.nodes].sort((a, b) => (a.ord ?? 1e9) - (b.ord ?? 1e9))) {
        if (g.groups.includes(n.id)) continue;
        const b = mk(n.name ?? n.id.replace(/_/g, " "), "", () => { set(b, b.classList.contains("off")); fit(); });
        b.dataset.id = n.id; if (n.colors && n.colors.text) b.style.color = n.colors.text; btns.push(b); // the text colour of its node
      }
      box.insertAdjacentElement("afterend", row);
    }
    // ELK's bends are offsets from both nodes, so a drag skews them. A dragged node's links drop
    // them and turn at right angles instead, until the next layout.
    cy.on("drag", "node", e => e.target.union(e.target.descendants()).connectedEdges()
      .filter(ed => ed.style("curve-style") !== "round-taxi")
      .forEach(ed => { ed.removeStyle(); ed.style({ "curve-style": "round-taxi", "taxi-radius": 8 }); }));

    // Hover: light the node, its links and neighbours; dim the rest; show the description.
    const tip = document.querySelector(".dg-tip") || document.body.appendChild(Object.assign(document.createElement("div"), { className: "dg-tip" }));
    // Driven by mousemove, not mouseover/mouseout: a fast move off the box sends the node no
    // mouseout, and Cytoscape then sends no mouseover when the mouse comes back to that node.
    let lit = null;
    const light = n => {
      if (n === lit) return;
      lit = n;
      cy.elements().removeClass("dim hl"); tip.style.display = "none"; box.style.cursor = "";
      if (!n) return;
      const hood = n.isEdge() ? n.union(n.connectedNodes()) : n.closedNeighborhood();
      cy.elements().not(hood).not(":parent").addClass("dim");
      hood.edges().addClass("hl");
      const d = n.data("desc");
      tip.textContent = d || ""; tip.style.display = d ? "block" : "none";
      box.style.cursor = n.isNode() && urls[n.id()] ? "pointer" : "";
    };
    cy.on("mousemove", e => {
      const t = e.target;
      light(t !== cy && ((t.isNode() && t.isChildless()) || (t.isEdge() && t.data("desc"))) ? t : null);
      tip.style.left = e.originalEvent.clientX + 12 + "px"; tip.style.top = e.originalEvent.clientY + 12 + "px";
    });
    box.addEventListener("mouseleave", () => light(null));
    // Cytoscape remembers where the box is on the page, and forgets on a scroll, a resize or a
    // change to the box. When text above moves the box without any of those, hover hits the
    // wrong place: forget on every move.
    box.addEventListener("mousemove", () => cy.renderer().invalidateContainerClientCoordsCache(), true);
    cy.on("tap", "node", e => { const u = urls[e.target.id()]; if (u) { tip.style.display = "none"; (opts.open || (x => location.assign(x)))(u); } });
    box.addEventListener("wheel", e => {
      if (!e.ctrlKey && !e.metaKey) return;
      e.preventDefault();
      const r = box.getBoundingClientRect();
      cy.zoom({ level: cy.zoom() * Math.exp(-e.deltaY / 200), renderedPosition: { x: e.clientX - r.left, y: e.clientY - r.top } });
    }, { passive: false });
    box.dg = cy;   // for tests, debugging and check()
    return cy;
  }

  // --- check: the layout rules of graph-check, on a drawn graph ----------------------------

  const hit = (a, b, pad = 1) => a.x1 + pad < b.x2 && b.x1 + pad < a.x2 && a.y1 + pad < b.y2 && b.y1 + pad < a.y2;
  // Does the segment p-q pass through box b (shrunk by pad)? Liang-Barsky clipping.
  function crosses(p, q, b, pad = 2) {
    let t0 = 0, t1 = 1;
    const dx = q.x - p.x, dy = q.y - p.y;
    for (const [d, n] of [[-dx, p.x - (b.x1 + pad)], [dx, (b.x2 - pad) - p.x], [-dy, p.y - (b.y1 + pad)], [dy, (b.y2 - pad) - p.y]]) {
      if (d === 0) { if (n < 0) return false; continue; }
      const t = n / d;
      if (d < 0) { if (t > t1) return false; if (t > t0) t0 = t; } else { if (t < t0) return false; if (t < t1) t1 = t; }
    }
    return t0 < t1;
  }

  // Returns one line per broken rule. Boxes are in graph units; the font check uses the zoom the page shows.
  function check(cy) {
    const out = [];
    const name = e => e.isNode() ? `"${e.data("label")}"` : `link ${e.source().data("label")} -> ${e.target().data("label")}${e.data("label") ? ` [${e.data("label")}]` : ""}`;
    const texts = [
      ...cy.nodes(":childless").map(n => ({ e: n, what: `node ${name(n)}`, b: n.boundingBox({ includeLabels: n.hasClass("dot") }) })),
      ...cy.nodes(":parent").map(n => { const b = n.boundingBox({ includeLabels: false }), h = FONT.node + 6;
        return { e: n, what: `group name "${n.data("label")}"`, b: { x1: b.x1 + 10, x2: b.x1 + 10 + groupW(n), y1: b.y1 - h, y2: b.y1 } }; }),
      ...cy.edges("[label]").map(e => ({ e, what: `text of ${name(e)}`, b: e.boundingBox({ includeNodes: false, includeEdges: false, includeLabels: true }) })),
    ];
    // R2: no text covers other text.
    for (let i = 0; i < texts.length; i++) for (let j = i + 1; j < texts.length; j++) {
      const a = texts[i], b = texts[j];
      if (a.e.isNode() && b.e.isNode() && (a.e.parent().same(b.e) || b.e.parent().same(a.e))) continue;
      if (hit(a.b, b.b)) out.push(`R2 overlap: ${a.what} covers ${b.what}`);
    }
    // R2: no link crosses a node, a label or a group name that is not its own.
    for (const e of cy.edges(":simple").not(".loop")) { // a loop stays next to its own node
      const s = e.sourceEndpoint(), d = e.targetEndpoint(), cp = e.controlPoints();
      // A link bent by one control point is drawn as a curve through points well inside that point: test the curve.
      const pts = cp && cp.length === 1 ? Array.from({ length: 41 }, (_, i) => { const u = i / 40;
          return { x: (1 - u) ** 2 * s.x + 2 * u * (1 - u) * cp[0].x + u * u * d.x, y: (1 - u) ** 2 * s.y + 2 * u * (1 - u) * cp[0].y + u * u * d.y }; })
        : [s, ...(e.segmentPoints() || cp || []), d];
      const ends = e.source().union(e.target());
      for (const t of texts) {
        if (t.e.same(e) || (t.e.isNode() && ends.contains(t.e))) continue;
        if (t.e.isParent() && ends.some(n => n.ancestors().contains(t.e)) && t.what.startsWith("node")) continue;
        if (pts.some((p, i) => i && crosses(pts[i - 1], p, t.b))) out.push(`R2 crossing: ${name(e)} crosses ${t.what}`);
      }
    }
    // R3: a graph that has to shrink to fit is no wider than 2:1 and no taller than 1:2.
    const bb = cy.elements().boundingBox(), r = cy.zoom() < 1.19 ? bb.w / bb.h : 1;
    if (r > 2) out.push(`R3 ratio: ${Math.round(bb.w)} x ${Math.round(bb.h)} is ${r.toFixed(1)} times as wide as tall (at most 2)`);
    if (r < 0.5) out.push(`R3 ratio: ${Math.round(bb.w)} x ${Math.round(bb.h)} is ${(1 / r).toFixed(1)} times as tall as wide (at most 2)`);
    // R4: the smallest text is at least 9 px when the whole graph fits the box. The page zooms in
    // past that, so this tests the graph, not the page.
    const px = Math.min(FONT.node, cy.edges("[label]").length ? FONT.edge : FONT.node) * (cy.scratch("fitZoom") ?? cy.zoom());
    if (px < 9) out.push(`R4 density: text is ${px.toFixed(1)} px when the whole graph fits (at least 9). Split the graph or cut text.`);
    return out;
  }

  const api = { parse, draw, check, ringPlace, dotSize };
  if (typeof window !== "undefined") window.DrawGraph = api;
  if (typeof module !== "undefined") module.exports = api;
})();
