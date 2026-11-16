/* preview.js - in VS Code's Markdown preview, draws each ```graph block with draw-graph.js.
 * The preview renders the fence as <pre><code class="language-graph">; this swaps it for the
 * drawn graph. VS Code replaces the page body on each edit and then fires
 * "vscode.markdown.updateContent", so the graphs are drawn again then.
 */
(function () {
  "use strict";
  let live = [];

  async function drawAll() {
    // Free the graphs the new body dropped. They hold window listeners.
    live = live.filter(cy => cy.container()?.isConnected || (cy.destroy(), false));
    for (const code of document.querySelectorAll("pre > code.language-graph")) {
      const pre = code.parentElement, wrap = document.createElement("div"), div = document.createElement("div");
      wrap.className = "dg-graph";
      // Keep the source line, so a click in the preview still jumps to the editor.
      if (pre.dataset.line) { wrap.dataset.line = pre.dataset.line; wrap.classList.add("code-line"); }
      wrap.append(div);
      pre.replaceWith(wrap);
      try { live.push(await DrawGraph.draw(div, code.textContent)); }
      catch (e) { div.textContent = "Graph error: " + e.message; div.className = "dg-err"; }
    }
  }

  window.addEventListener("vscode.markdown.updateContent", drawAll);
  PlanPreview.preview();   // hover card and popup of a research link, the feedback toggle
  CodeReference.preview();   // Cmd+Shift+C answers with the source lines of the selection
  document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", drawAll) : drawAll();
})();
