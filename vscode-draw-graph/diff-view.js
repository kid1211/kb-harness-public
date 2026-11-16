/* diff-view.js - the page of the rendered Markdown diff (extension.js). It draws the diff the
 * extension sends, whole, draws graph blocks, and marks each change on
 * the strip at the right. A click on a mark scrolls to the change. Asked {type: "ref"}, it
 * answers with the source lines of the selection (code-reference.js).
 */
(function () {
  "use strict";
  const vscode = acquireVsCodeApi(), md = document.getElementById("md"), ruler = document.getElementById("ruler");
  let live = [];

  function graph(code) {
    const box = document.createElement("div"), div = document.createElement("div");
    box.className = "dg-graph"; box.append(div);
    if (code.parentElement.dataset.srcLines) box.dataset.srcLines = code.parentElement.dataset.srcLines;
    code.parentElement.replaceWith(box);
    const draw = () => !div.childElementCount && DrawGraph.draw(div, code.textContent).then(cy => live.push(cy), e => { div.textContent = "Graph error: " + e.message; div.className = "dg-err"; });
    // A graph in a closed fold has no size to lay out in: it is drawn when the fold opens.
    const shut = box.closest("details");
    shut ? shut.addEventListener("toggle", () => shut.open && draw()) : draw();
  }

  // The strip stands in for the scroll bar: a box shows the part in view, a click scrolls there.
  const view = document.createElement("div");
  view.className = "view";
  const place = () => { const h = document.documentElement.scrollHeight;
    view.style.top = scrollY / h * 100 + "%"; view.style.height = innerHeight / h * 100 + "%"; };
  addEventListener("scroll", place);
  ruler.onclick = e => e.target === ruler && scrollTo(0, e.clientY / innerHeight * document.documentElement.scrollHeight - innerHeight / 2);

  function marks() {
    ruler.replaceChildren(view);
    place();
    const h = document.documentElement.scrollHeight;
    for (const b of md.querySelectorAll(":scope > .md-ins, :scope > .md-del, :scope > .md-chg")) {
      const m = document.createElement("div");
      m.className = "mark " + b.className;
      m.style.top = (b.offsetTop / h * 100) + "%";
      m.style.height = Math.max(0.4, b.offsetHeight / h * 100) + "%";
      m.onclick = () => b.scrollIntoView({ block: "center" });
      ruler.append(m);
    }
  }

  window.addEventListener("message", e => {
    if (e.data.type === "ref") return vscode.postMessage({ type: "ref", lines: CodeReference.diffLines() });
    const y = scrollY;
    live.forEach(cy => cy.destroy()); live = [];
    // id-hover: the cards the extension sends mark the terms and IDs, by the rules of the mod (preview-cards R2).
    const html = MarkdownDiff.render(e.data.old, e.data.new, { lines: true });
    md.innerHTML = EmojiBullets.apply(window.IdCards && window.IdCore ? IdCards.apply(html, IdCards.revive(e.data.cards), IdCore) : html);
    // A changed graph comes as the old one removed, then the new one added. Show one changed
    // block instead: the graph text with its changed lines marked, then the new graph drawn.
    for (const c of md.querySelectorAll(".md-del > pre > code.language-graph")) {
      const del = c.closest(".md-del"), ins = del.nextElementSibling;
      const n = ins?.matches(".md-ins") && ins.querySelector(":scope > pre > code.language-graph");
      if (!n) continue;
      const chg = document.createElement("div"), pre = document.createElement("pre");
      chg.className = "md-chg";
      if (ins.dataset.srcLines) chg.dataset.srcLines = ins.dataset.srcLines;
      for (const p of Diff.diffLines(c.textContent, n.textContent))
        pre.append(p.added || p.removed ? Object.assign(document.createElement(p.added ? "ins" : "del"), { textContent: p.value }) : p.value);
      chg.append(pre, n.parentElement);
      del.replaceWith(chg); ins.remove();
    }
    // A removed graph is folded, and drawn when opened.
    for (const c of md.querySelectorAll(".md-del pre > code.language-graph")) {
      const pre = c.parentElement, d = document.createElement("details");
      d.innerHTML = "<summary>Old graph, removed or replaced. Click to show.</summary>";
      pre.replaceWith(d); d.append(pre);
    }
    md.querySelectorAll("pre > code.language-graph").forEach(graph);
    if (!md.querySelector(".md-ins, .md-del, .md-chg")) md.insertAdjacentHTML("afterbegin", '<p class="md-same">No changes.</p>');
    scrollTo(0, y);
    marks();
  });
  // The live hint of the status bar follows the selection (code-reference R11).
  let selT;
  document.addEventListener("selectionchange", () => { clearTimeout(selT); selT = setTimeout(() => vscode.postMessage({ type: "sel", lines: CodeReference.diffLines() }), 100); });
  // A fold that opens or closes, a graph drawn, or a resize moves the blocks.
  new ResizeObserver(marks).observe(md);
  vscode.postMessage("ready");
})();
