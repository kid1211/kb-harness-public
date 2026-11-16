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
    const nodes = {}, groups = new Set(), edges = [];
    let n = 0;
    const node = id => (nodes[id] ??= { id, label: id.replace(/_/g, " ") });
    for (const raw of txt.split("\n")) {
      const l = raw.trim(); let m;
      if (!l || l.startsWith("#")) continue;
      if ((m = l.match(/^(external|begin|end|fail|skill|hook)\s+(?!->)(.+)$/))) m[2].split(/\s+/).forEach(id => {
        const k = m[1], nd = node(id);
        if (k === "external" || k === "skill" || k === "hook") nd.external = true;
        if (k !== "external") nd.kind = k;
      });
      else if ((m = l.match(/^\[(.+?)\]\s*(.*)$/))) m[2].split(/\s+/).filter(Boolean).forEach(id => { node(id).parent = m[1]; groups.add(m[1]); });
      else if ((m = l.match(/^(\S+)\s*->\s*(.+)$/))) m[2].split(/,(?![^\[]*\])/).forEach(it => { // commas inside [label] do not split
        const [, b, label] = it.trim().match(/^(\S+)(?:\s*\[(.+)\])?$/) || [];
        if (!b) return console.warn("draw-graph: bad target", it);
        node(m[1]).ord ??= n++; node(b).ord ??= n++;
        edges.push({ source: m[1], target: b, label });
      });
      else if ((m = l.match(/^(\S+?)\.run:\s*(.+)$/))) node(m[1]).run = m[2];
      else if ((m = l.match(/^(\S+):\s+(.+)$/))) node(m[1]).desc = m[2]; // an ID may hold a colon, as p-req:grill
      else console.warn("draw-graph: unread line", l);
    }
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
    return { nodes: Object.values(nodes), groups: [...groups], edges };
  }

  const STYLE = `
.dg { position: relative; width: 100%; }
.dg-flip { position: absolute; top: 6px; right: 6px; z-index: 5; font: 13px/1 system-ui, sans-serif; cursor: pointer;
  padding: 4px 8px; border-radius: 5px; border: 1px solid var(--dg-group, #bbb); background: var(--dg-bg, #fff); color: var(--dg-fg, #1d1d1b); }
.dg-reset { right: 104px; }
.dg-tip { position: fixed; z-index: 10; max-width: 320px; padding: 6px 9px; border-radius: 5px; font-size: 13px;
  line-height: 1.4; pointer-events: none; display: none; background: #222; color: #fff; }`;
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
  const wrapWidth = t => Math.max(...t.split("\n").flatMap(l => l.split(" ").reduce((ls, w) => {
    const cur = ls[ls.length - 1], next = cur ? cur + " " + w : w;
    if (cur && textWidth(next) > WRAP) ls.push(w); else ls[ls.length - 1] = next;
    return ls; }, [""])).map(textWidth));
  const groupW = n => n.data("label").length * FONT.node * 0.6; // about the width of a group's name

  // Lay the graph out with ELK in one direction, "DOWN" or "RIGHT", and draw it at those positions.
  async function layout(cy, g, box, dir) {
    cy.remove(".loopnote");
    cy.edges().removeStyle();
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
        labels: e.label ? [{ text: e.label, width: e.label.length * FONT.edge * 0.58 + 6, height: FONT.edge + 6 }] : [] }))
        .filter(e => e.sources[0] !== e.targets[0]),
    });
    const pos = {};
    const place = (ns, ox, oy) => ns.forEach(n => {
      const x = ox + n.x, y = oy + n.y;
      if (n.children?.length) place(n.children, x, y); else pos[n.id] = { x: x + n.width / 2, y: y + n.height / 2 };
    });
    place(res.children, 0, 0);
    // The box is as tall as the graph at the width it gets, up to 1.5 windows: a top-down graph scrolls with the page.
    const z = Math.max(MIN_ZOOM, Math.min(1.2, (box.clientWidth - 40) / res.width));
    box.style.height = Math.max(140, Math.min(res.height * z + 60, innerHeight * 1.5)) + "px";
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
      // The label goes where ELK left room for it, not at the middle of the line.
      const l = e.labels?.[0];
      if (l && l.x != null) { const m = edge.midpoint();
        edge.style({ "text-margin-x": l.x + l.width / 2 - m.x, "text-margin-y": l.y + l.height / 2 - m.y }); }
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
    const cy = cytoscape({
      container: box, userZoomingEnabled: false, // the wheel scrolls the page; pinch or Ctrl+wheel zooms (below)
      elements: [...g.groups.map(id => ({ data: { id, label: id.replace(/_/g, " ") } })),
        ...g.nodes.map(n => ({ data: { ...n }, classes: [urls[n.id] && "link", n.external && "external", n.state && "state", n.id.endsWith("?") && "decision", ["begin", "end", "fail"].includes(n.kind) ? "terminal " + n.kind : n.kind, n.kind && "icon"].filter(Boolean).join(" ") })),
        ...g.edges.map((e, i) => ({ data: { ...e, id: "e" + i } })).filter(e => e.data.source !== e.data.target)],
      layout: { name: "preset" },
      style: [
        { selector: "node", style: { label: "data(label)", shape: "round-rectangle", width: "label", height: 26, padding: 7,
          "text-valign": "center", "font-size": FONT.node, color: C.fg, "background-color": C.node, "border-width": 1, "border-color": C.border } },
        { selector: "node.external", style: { "background-color": C.comp } },
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
        { selector: "edge[label]", style: { label: "data(label)", "font-size": FONT.edge, color: C.fg, "text-rotation": "none",
          "text-background-color": C.bg, "text-background-opacity": 1, "text-background-padding": 1 } },
        // A loop inside a node (R27) curls out of its right side, with its text beyond the curl.
        { selector: "node.loopnote", style: { "background-opacity": 0, "border-width": 0, "font-size": FONT.edge, width: "label", height: "label", padding: 2 } },
        { selector: ".dim", style: { opacity: .15 } },
        { selector: "edge.hl", style: { "line-color": C.hl, "target-arrow-color": C.hl, width: 2.5 } },
      ],
    });

    // Top to bottom first; the button flips it to left to right and back.
    let dir = opts.direction || "DOWN";
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
      const hood = n.closedNeighborhood();
      cy.elements().not(hood).not(":parent").addClass("dim");
      hood.edges().addClass("hl");
      const d = n.data("desc");
      tip.textContent = d || ""; tip.style.display = d ? "block" : "none";
      box.style.cursor = urls[n.id()] ? "pointer" : "";
    };
    cy.on("mousemove", e => {
      light(e.target !== cy && e.target.isNode() && e.target.isChildless() ? e.target : null);
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
      ...cy.nodes(":childless").map(n => ({ e: n, what: `node ${name(n)}`, b: n.boundingBox({ includeLabels: false }) })),
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
      const pts = [e.sourceEndpoint(), ...(e.segmentPoints() || e.controlPoints() || []), e.targetEndpoint()];
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

  const api = { parse, draw, check };
  if (typeof window !== "undefined") window.DrawGraph = api;
  if (typeof module !== "undefined") module.exports = api;
})();
