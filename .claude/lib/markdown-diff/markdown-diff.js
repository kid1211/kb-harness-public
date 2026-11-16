/* markdown-diff: two versions of a Markdown file as rendered Markdown, with the changes marked.
 *
 *   <script src="marked.min.js"></script> <script src="diff.min.js"></script>
 *   <script src="/assets/markdown-diff.js"></script>
 *   el.innerHTML = MarkdownDiff.render(oldText, newText);       // uses the globals marked and Diff
 *   MarkdownDiff.render(a, b, { marked, Diff })                // or pass them (node tests)
 *   MarkdownDiff.fold(el);                                     // fold the unchanged blocks away
 *
 * Each top-level block (a paragraph, a heading, a list, a code block) is one unit.
 * jsdiff pairs the old blocks with the new ones. A block only in the new text is wrapped
 * in <div class="md-ins">, a block only in the old text in <div class="md-del">. A block
 * that changed in place is <div class="md-chg">, with its changed words in <ins> and <del>.
 * Code blocks (graph blocks too) never merge: the old one shows as removed, the new as added.
 * YAML front matter becomes a key | value table first (frontmatter), so it diffs row by row.
 * The VS Code extension runs the same frontmatter on its normal preview.
 *
 * Plan: plans/markdown-diff/
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.MarkdownDiff = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const blocks = (marked, text) => marked.lexer(text || "").filter(t => t.type !== "space");
  const key = t => t.raw.trim();

  // HTML split into tags and words, so a word diff never cuts through a tag.
  const tokens = html => html.match(/<[^>]+>|[\p{L}\p{N}_]+|[^\p{L}\p{N}_<\s]|\s+/gu) || [];

  // htmldiff: compare the two rendered blocks token by token. Tags are kept from the new
  // side; removed words go in <del>, added words in <ins>.
  function wordDiff(Diff, a, b) {
    let out = "";
    for (const part of Diff.diffArrays(tokens(a), tokens(b))) {
      for (const run of runs(part.value)) {
        if (run.tag) { if (!part.removed) out += run.text; }
        else if (part.added) out += `<ins>${run.text}</ins>`;
        else if (part.removed) out += `<del>${run.text}</del>`;
        else out += run.text;
      }
    }
    return out;
  }
  function runs(list) {          // consecutive words as one run, each tag on its own
    const out = [];
    for (const t of list) {
      const tag = t[0] === "<";
      if (!tag && out.length && !out[out.length - 1].tag) out[out.length - 1].text += t;
      else out.push({ tag, text: t });
    }
    return out;
  }

  // ponytail: a changed block pairs with the new block at the same place in a replaced run.
  // A run that inserts one block and edits the next may pair the wrong two; then the
  // word diff shows more red and green than it should, but nothing is lost.
  function similar(Diff, a, b) {
    let same = 0, all = 0;
    for (const p of Diff.diffWords(a, b)) { all += p.value.length; if (!p.added && !p.removed) same += p.value.length; }
    return all ? same / all : 1;
  }

  // The YAML front matter at the top of text (--- ... ---) as a Markdown key | value table.
  // A top-level value stays Markdown. A nested value shows one code line per YAML line.
  // ponytail: line-based, not a YAML parser; flow lists and multi-line quoted strings show raw.
  const FM = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(\r?\n|$)/;
  function frontmatter(text) {
    const m = FM.exec(text || "");
    if (!m) return text;
    const rows = [];
    for (const line of m[1].split(/\r?\n/)) {
      const kv = /^([^\s#:][^:]*):(?:\s+(.*))?$/.exec(line);
      if (kv) rows.push({ key: kv[1], value: (kv[2] || "").trim(), more: [] });
      else if (line.trim() && !line.trim().startsWith("#") && rows.length) rows[rows.length - 1].more.push(line);
    }
    if (!rows.length) return text;
    const pipe = s => s.replace(/\|/g, "\\|");
    const cell = r => {
      if (/^[|>][+-]?$/.test(r.value)) return pipe(r.more.map(l => l.trim()).join(" "));   // a block scalar
      const code = r.more.map(l => "`" + pipe(l.replace(/^ +/, s => "\u00a0".repeat(s.length))) + "`");
      return [r.value && pipe(r.value), ...code].filter(Boolean).join("<br>");
    };
    return "| Key | Value |\n|---|---|\n" + rows.map(r => `| ${r.key} | ${cell(r)} |`).join("\n") +
      "\n\n" + text.slice(m[0].length);
  }

  // The 1-based lines, "start-end", of each block of list in src, the file as written, where
  // text is src after frontmatter(). A block of the front matter table is the whole front
  // matter. Blocks are found in order, so a block marked never finds (a link definition) is skipped.
  function spans(src, text, list) {
    const nl = s => (s.match(/\n/g) || []).length;
    const fm = text === src ? "" : FM.exec(src)[0];
    const table = fm ? nl(text.slice(0, text.length - (src.length - fm.length))) : 0;
    let pos = 0;
    return list.map(t => {
      const at = text.indexOf(t.raw, pos);
      if (at >= 0) pos = at;
      const s = nl(text.slice(0, pos)) + 1, e = s + nl(t.raw.trimEnd());
      if (at >= 0) pos += t.raw.length;
      if (fm && s <= table) return [1, nl(fm.trimEnd()) + 1];
      return [s + nl(fm) - table, e + nl(fm) - table];
    });
  }

  // deps.lines: each block gets data-src-lines="start-end", its lines in newText. A removed
  // block gets the start of the next block still in the file (plans/vscode/components/code-reference R4).
  function render(oldText, newText, deps) {
    const marked = (deps && deps.marked) || globalThis.marked;
    const Diff = (deps && deps.Diff) || globalThis.Diff;
    const src = newText || "";
    oldText = frontmatter(oldText); newText = frontmatter(newText);
    const a = blocks(marked, oldText), b = blocks(marked, newText);
    const sp = deps && deps.lines ? spans(src, newText || "", b) : null;
    const near = k => k < sp.length ? sp[k][0] : sp.length ? sp[sp.length - 1][1] : 1;
    const at = (k, whole) => !sp ? "" : ` data-src-lines="${whole && k < sp.length ? sp[k].join("-") : near(k) + "-" + near(k)}"`;
    const tag = (h, k) => sp ? h.replace(/^\s*<[a-zA-Z][\w-]*/, m => m + at(k, true)) : h;
    // One block at a time, with its side's reference links ([x]: url) still known.
    const one = links => t => marked.parser(Object.assign([t], { links }), { gfm: true });
    const oldHtml = one(marked.lexer(oldText || "").links), html = one(marked.lexer(newText || "").links);
    const byKey = (list) => list.map(key);
    const out = [];
    let i = 0, j = 0;
    const parts = Diff.diffArrays(byKey(a), byKey(b));
    for (let p = 0; p < parts.length; p++) {
      const part = parts[p], n = part.count;
      if (!part.added && !part.removed) {
        for (let k = 0; k < n; k++) out.push(tag(html(b[j + k]), j + k));
        i += n; j += n;
        continue;
      }
      // A removed run followed by an added run is a replacement: pair blocks in place.
      const next = parts[p + 1];
      const del = part.removed ? a.slice(i, i + n) : [];
      const ins = part.added ? b.slice(j, j + n) : (next && next.added ? b.slice(j, j + next.count) : []);
      if (part.removed && next && next.added) p++;
      for (let k = 0; k < Math.max(del.length, ins.length); k++) {
        const o = del[k], w = ins[k];
        if (o && w && o.type === w.type && o.type !== "code" && similar(Diff, key(o), key(w)) > 0.4) {
          out.push(`<div class="md-chg"${at(j + k, true)}>${wordDiff(Diff, oldHtml(o), html(w))}</div>`);
        } else {
          if (o) out.push(`<div class="md-del"${at(j + k, false)}>${oldHtml(o)}</div>`);
          if (w) out.push(`<div class="md-ins"${at(j + k, true)}>${html(w)}</div>`);
        }
      }
      i += del.length; j += ins.length;
    }
    return out.join("\n");
  }

  // In a page: fold each run of unchanged blocks in el into one "N unchanged blocks" row, like
  // a code diff's folded lines. The heading above a change stays, so a change shows which section it is in.
  function fold(el) {
    const blocks = [...el.children];
    const changed = b => b.matches(".md-ins, .md-del, .md-chg");
    const keep = new Set(blocks.filter(changed));
    blocks.forEach((b, i) => {
      if (!changed(b)) return;
      for (let j = i - 1; j >= 0; j--) {
        if (blocks[j].matches("h1,h2,h3,h4,h5,h6")) { keep.add(blocks[j]); break; }
        if (changed(blocks[j])) break;
      }
    });
    let run = [];
    const close = () => {
      if (!run.length) return;
      const d = el.ownerDocument.createElement("details");
      d.className = "md-fold";
      d.innerHTML = `<summary>${run.length} unchanged block${run.length > 1 ? "s" : ""}</summary>`;
      run[0].before(d);
      d.append(...run);
      run = [];
    };
    for (const b of blocks) keep.has(b) ? close() : run.push(b);
    close();
  }

  return { render, fold, frontmatter, tokens, wordDiff };
});
