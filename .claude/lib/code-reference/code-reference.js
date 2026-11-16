/* code-reference: Cmd+Shift+C copies @<full path>#L12-20 of the selected lines, for the user to
 * paste into a Claude Code session. No /ide connection is needed.
 *   const CR = require("./code-reference.js")   // the extension, in node
 *   CodeReference.preview()                     // VS Code's Markdown preview, a preview script
 *   CodeReference.diffLines()                   // the Markdown Diff page
 * Lines are 1-based and inclusive: { start, end }. null means nothing selected.
 *
 * Plan: plans/vscode/components/code-reference/
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.CodeReference = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  // The preview has no message channel to the extension, so the key starts a copy and the
  // page answers in the clipboard with this mark (R5).
  const MARK = "TalkToClaude-lines:";

  const span = l => l.start === l.end ? `L${l.start}` : `L${l.start}-${l.end}`;

  // R1, R9: a file on disk gets #L, a git version names its ref, either side of a diff.
  const reference = (path, lines, ref) => ref ? `@${path} (version at ${ref}, ${span(lines)})` : `@${path}#${span(lines)}`;

  // R10: the status-bar line.
  const note = (name, lines, ref) => lines
    ? `TalkToClaude: copied ${reference(name, lines, ref).slice(1)}. Switch to Claude and press Cmd+V.`
    : hint(null);

  // R11: the live hint before a press. No lines: nothing selected, or a place that cannot see.
  const hint = lines => lines ? `TalkToClaude: ${span(lines)} selected. Press Cmd+Shift+C.` : "TalkToClaude: select text, then press Cmd+Shift+C.";

  // The git ref of a document that is not a file on disk, or "" for a file (R9).
  // git: URIs carry {path, ref} in the query. "~" and "" are the index.
  function refOf(uri) {
    if (uri.scheme === "file") return "";
    if (uri.scheme === "git-head") return "HEAD";
    if (uri.scheme === "git") {
      try { const r = JSON.parse(uri.query).ref; return !r || r === "~" ? "the index" : /^[0-9a-f]{40}$/.test(r) ? r.slice(0, 7) : r; } catch { return "git"; }
    }
    return uri.scheme;
  }

  // The lines of a text editor's selections (0-based positions). A selection that ends at the
  // start of a line does not take that line. All empty: null (R8).
  function editorLines(selections) {
    const s = selections.filter(x => !x.isEmpty);
    if (!s.length) return null;
    const start = Math.min(...s.map(x => x.start.line));
    const end = Math.max(...s.map(x => x.end.character === 0 && x.end.line > x.start.line ? x.end.line - 1 : x.end.line));
    return { start: start + 1, end: end + 1 };
  }

  // Drop blank lines at the end of a range. line(n) gives the text of 1-based line n.
  function trimEnd(lines, line) {
    let end = lines.end;
    while (end > lines.start && !line(end).trim()) end--;
    return { start: lines.start, end };
  }

  // The answer of the preview page in the clipboard: { uri, lines }, null for nothing
  // selected, undefined for no answer.
  function parseMark(text) {
    if (!text || !text.startsWith(MARK)) return undefined;
    const m = /^(.*)#(\d+)-(\d+)$/.exec(text.slice(MARK.length));
    return m ? { uri: m[1], lines: { start: +m[2], end: +m[3] } } : null;
  }

  // Preview: the start block's data-line, to the line before the next block after the end
  // block. data-line is 0-based. blocks are in page order; each has line and contains(b).
  function previewLines(first, last, blocks) {
    const next = blocks.slice(blocks.indexOf(last) + 1).find(b => !last.contains(b));
    const end = next ? next.line - 1 : last.line;
    return { start: first.line + 1, end: Math.max(first.line, end) + 1 };
  }

  // The selection's two ends as the closest elements with attr, or null.
  function ends(attr) {
    const sel = document.getSelection();
    if (!sel || sel.isCollapsed || !sel.rangeCount) return null;
    const r = sel.getRangeAt(0), up = n => (n.nodeType === 1 ? n : n.parentElement)?.closest(`[${attr}]`);
    const a = up(r.startContainer), b = up(r.endContainer);
    return a && b ? [a, b] : null;
  }

  // In the preview page: a Cmd+Shift+C arms the next copy, which writes the mark instead of
  // the text. A normal copy is left alone.
  function preview() {
    if (!document.getElementById("vscode-markdown-preview-data")) return;   // not the preview, such as the Markdown Diff
    let armed = 0;
    addEventListener("keydown", e => {
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.code === "KeyC") armed = Date.now();
    }, true);
    document.addEventListener("copy", e => {
      if (Date.now() - armed > 2000) return;
      armed = 0;
      const ab = ends("data-line"), blocks = [...document.querySelectorAll("[data-line]")];
      const box = el => ({ el, line: +el.dataset.line, contains: b => el.contains(b.el) });
      const all = blocks.map(box), at = el => all[blocks.indexOf(el)];
      const lines = ab && previewLines(at(ab[0]), at(ab[1]), all);
      const source = JSON.parse(document.getElementById("vscode-markdown-preview-data")?.dataset.settings || "{}").source;
      e.clipboardData.setData("text/plain", MARK + (lines && source ? `${source}#${lines.start}-${lines.end}` : "none"));
      e.preventDefault();
    }, true);
  }

  // In the Markdown Diff page: each block carries data-src-lines="start-end" (markdown-diff.js).
  function diffLines() {
    const ab = ends("data-src-lines");
    if (!ab) return null;
    const [s] = ab[0].dataset.srcLines.split("-").map(Number), [, e] = ab[1].dataset.srcLines.split("-").map(Number);
    return { start: s, end: Math.max(s, e) };
  }

  return { MARK, reference, note, hint, refOf, editorLines, trimEnd, parseMark, previewLines, preview, diffLines };
});
