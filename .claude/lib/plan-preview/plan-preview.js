/* plan-preview: a plan reads well in VS Code's Markdown preview.
 *   html = PlanPreview.apply(html, { dir, readFile, render, statesOnly })   // node, after markdown-it renders
 *   PlanPreview.setFeedback(text, n, value, reason)                         // node, the URI handler's write
 *   PlanPreview.preview()                                                   // the page: popup, toggle, marks
 * Parts of a state (Guard, Invariants, Effect) fold with a native <details>. A research link
 * gets its answer page embedded hidden, because a preview script cannot fetch a file.
 * The toggle is a vscode:// link: the only way a preview click reaches the extension.
 *
 * Plan: plans/vscode/components/plan-preview/
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.PlanPreview = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const BASE = "vscode://local.draw-graph-preview/feedback";
  const VALUES = ["agree", "disagree", "not_checked"];   // the toggle
  // p-research writes pending_review when it answers a disagree again: The user reviews it, or sets not checked
  const FEEDBACK = [...VALUES, "pending_review"];
  const LABEL = { agree: "agree", disagree: "disagree", not_checked: "not checked" };
  // The mark of a research question is its bullet, as a requirement's status is (the user, 2026-10-24).
  // The marks are in .claude/lib/palette/kitchen-sink.md, 6b.
  const OPEN = "❓", DEFER = "⚠️";
  const MARK = { agree: "🟢", disagree: "🔴", not_checked: "⚪", pending_review: "🟠" };
  const ROWS = [[OPEN, "open, not checked by you"], [MARK.not_checked, "answered, not checked by you"], [MARK.agree, "you agree"],
    [MARK.disagree, "you disagree: research it again"], [MARK.pending_review, "answered again: review it"], [DEFER, "deferred: left for later"]];
  // The user's feedback wins. With none, the status picks the mark.
  const markOf = (status, feedback) => feedback && feedback !== "not_checked" && MARK[feedback] ? MARK[feedback] : status === "open" ? OPEN : MARK.not_checked;
  // The hover legend, with the classes of emoji-bullets.css: the row of the mark stands out, the reason of a disagree first.
  const legend = (rows, on, first = "") => `<span class="eb-legend" aria-hidden="true">` +
    (first ? `<span class="eb-first">${esc(first)}</span>` : "") +
    rows.map(([e, t]) => `<span class="eb-row${e === on ? " eb-on" : ""}">${e} ${t}</span>`).join("") + "</span>";
  const bullet = (attrs, e, extra = "") => `<li${attrs} style="list-style-type: '${e} '" data-legend=""${extra}>`;
  const esc = s => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

  // ---- the link, and the write it causes

  // Encoded twice: VS Code decodes uri.query once before the handler reads it, so an & or = in a reason
  // would split the query.
  const enc = s => encodeURIComponent(encodeURIComponent(s));
  const feedbackUri = (file, q, value, reason) =>
    `${BASE}?file=${enc(file)}&q=${q}&value=${value}` + (reason ? `&reason=${enc(reason)}` : "");

  function parseFeedbackUri(query) {
    const p = new URLSearchParams(query), value = p.get("value"), q = Number(p.get("q"));
    if (!p.get("file") || !Number.isInteger(q) || !VALUES.includes(value)) return null;
    return { file: p.get("file"), q, value, reason: p.get("reason") || "" };
  }

  // The text of "## Q<n>." up to the next "## " heading, or null.
  function questionSection(text, n) {
    const start = text.search(new RegExp(`^## Q${n}\\.`, "m"));
    if (start < 0) return null;
    const next = text.slice(start + 3).search(/^## /m);
    return next < 0 ? text.slice(start) : text.slice(start, start + 3 + next);
  }

  // Set the User feedback and Disagree reason lines of Q<n>. A bad value, a disagree with no
  // reason, or a missing question changes nothing. Agree and not checked keep the reason, for a later disagree,
  // and add the change to its end, so the next disagree shows it.
  // day: YYYY-MM-DD HH:MM of the change, now by default. Each change adds a dated line to Feedback history.
  const now = () => new Date().toLocaleString("sv").slice(0, 16);
  // The disagree reason after a move to agree or not checked: the change goes on its end, between === lines.
  const keptReason = (reason, value, day) => reason && `${/(^|\n)===$/.test(reason) ? reason : reason + "\n==="}\n${day}: changed to ${value}\n===`;
  // A reason may have many lines. Blank lines go, and spaces in a line close up.
  const tidy = r => String(r || "").split(/\r?\n/).map(l => l.replace(/\s+/g, " ").trim()).filter(Boolean).join("\n");
  function setFeedback(text, n, value, reason, day = now()) {
    const sec = questionSection(text, n);
    reason = tidy(reason);
    if (sec === null || !VALUES.includes(value) || (value === "disagree" && !reason)) return text;
    const was = fields(sec);
    if (was.feedback === value && (value !== "disagree" || was.reason === reason)) return text;
    let lines = sec.split("\n");
    // A value of many lines: its first line on the field, each other line a sub-item under it.
    const set = (label, val) => {
      const [first, ...rest] = val ? val.split("\n") : [""];
      const line = [`- **${label}:**${first ? " " + first : ""}`, ...rest.map(l => "  - " + l)].join("\n");
      const i = lines.findIndex(l => l.startsWith(`- **${label}:**`));
      if (i >= 0) {
        let k = i;
        while (label === "Disagree reason" && lines[k + 1] && /^\s+- /.test(lines[k + 1])) k++;
        return void lines.splice(i, k - i + 1, line);
      }
      let j = lines.findIndex(l => l.startsWith("- **"));
      if (j < 0) return void lines.splice(1, 0, line);
      while (lines[j + 1] && lines[j + 1].startsWith("- **")) j++;
      lines.splice(j + 1, 0, line);
    };
    set("User feedback", value);
    set("Disagree reason", value === "disagree" ? reason : keptReason(was.reason, value, day));
    set("Feedback history", "");
    lines = lines.join("\n").split("\n");
    let h = lines.findIndex(l => l.startsWith("- **Feedback history:**"));
    while (lines[h + 1] && /^\s+- /.test(lines[h + 1])) h++;
    lines.splice(h + 1, 0, `  - ${day}: changed to ${value}${value === "disagree" ? ", because " + reason.split("\n")[0] : ""}`);
    return text.replace(sec, () => lines.join("\n"));
  }

  // The Disagree reason: its field line, and the sub-items under it, one line each.
  const reasonOf = sec => {
    const lines = sec.split("\n"), i = lines.findIndex(l => l.startsWith("- **Disagree reason:**"));
    if (i < 0) return "";
    const out = [lines[i].slice("- **Disagree reason:**".length)];
    for (let k = i + 1; lines[k] && /^\s+- /.test(lines[k]); k++) out.push(lines[k].replace(/^\s+- /, ""));
    return tidy(out.join("\n"));
  };
  const fields = sec => {
    const f = l => (sec.match(new RegExp(`^- \\*\\*${l}:\\*\\*[ \\t]*(.*)$`, "m")) || [, ""])[1].trim();
    return { title: sec.split("\n")[0].replace(/^## /, ""), status: f("Status"), confidence: f("Confidence"),
      feedback: FEEDBACK.includes(f("User feedback")) ? f("User feedback") : "not_checked", reason: reasonOf(sec) };
  };

  // ---- folded parts, and the states-only view

  // The html between a heading and the next heading of its level, as [start, end], or null.
  function range(html, title, tag) {
    const m = new RegExp(`<${tag}[^>]*>\\s*${title}\\s*</${tag}>`).exec(html);
    if (!m) return null;
    const start = m.index + m[0].length, next = html.slice(start).search(new RegExp(`<${tag}[\\s>]`));
    return [start, next < 0 ? html.length : start + next];
  }

  const PART = /<li(?:\s[^>]*)?>\s*(?:<p[^>]*>)?\s*<strong>(Guard|Invariants|Effect):<\/strong>/g;

  // The index of the </li> that closes the <li> whose content starts at `from`.
  function liEnd(html, from) {
    const re = /<li[\s>]|<\/li>/g;
    let depth = 1, m;
    re.lastIndex = from;
    while ((m = re.exec(html))) if ((depth += m[0] === "</li>" ? -1 : 1) === 0) return m.index;
    return html.length;
  }

  // Replace each part <li> by fn(name, label, rest); label is "<strong>Guard:</strong>".
  function mapParts(html, fn) {
    const re = new RegExp(PART.source, "g");
    let out = "", i = 0, m;
    while ((m = re.exec(html))) {
      const inner = m.index + html.slice(m.index).indexOf(">") + 1, close = liEnd(html, inner);
      const body = html.slice(inner, close).replace(/^\s*<p[^>]*>/, ""), cut = body.indexOf("</strong>") + 9;
      out += html.slice(i, m.index) + fn(m[1], body.slice(0, cut), body.slice(cut));
      i = re.lastIndex = close + 5;
    }
    return out + html.slice(i);
  }

  function foldParts(html, statesOnly) {
    const r = range(html, "State deep dive", "h2");
    if (!r) return html;
    const chunks = html.slice(r[0], r[1]).split(/(?=<h3[\s>])/).map(chunk => {
      if (!statesOnly) return mapParts(chunk, (n, label, rest) => `<li class="pp-part"><details class="pp-part"><summary>${label}</summary>${rest}</details></li>`);
      const parts = {};
      const rest = mapParts(chunk, (n, label, body) => ((parts[n] = body.trim()), "")).replace(/<ul[^>]*>\s*<\/ul>\n?/g, "");
      const links = ["Effect", "Invariants"].filter(n => parts[n]).map(n => `<span class="pp-link" tabindex="0">${n}<div class="pp-tip">${parts[n]}</div></span>`);
      return links.length ? rest + `<div class="pp-links">${links.join(" ")}</div>\n` : rest;
    });
    return html.slice(0, r[0]) + chunks.join("") + html.slice(r[1]);
  }

  // ---- research questions

  function toggle(id, file, n, f) {
    const links = VALUES.map(v => `<a class="pp-pick${f.feedback === v ? " pp-on" : ""}" data-value="${v}" href="${esc(feedbackUri(file, n, v))}"` +
      (v === "disagree" && f.reason ? ` title="${esc(f.reason)}"` : "") + `>${LABEL[v]}</a>`);
    return `<div class="pp-fb" data-pp-id="${id}">Your feedback: ${links.join(" ")}</div>`;
  }

  // A link into another repo resolves from the main checkout only. From a worktree, read it as from the main checkout.
  // ponytail: knows only the .claude/worktrees/<name>/ layout
  function answerFile(dir, href, readFile) {
    const path = require("path"), file = path.resolve(dir, href), wt = dir.match(/^(.*)\/\.claude\/worktrees\/[^/]+(\/.*)?$/);
    if (readFile(file) || !wt) return file;
    return path.resolve(wt[1] + (wt[2] || ""), href);
  }

  function questions(html, ctx) {
    const r = ctx.dir && range(html, "Research questions", "h2");
    if (!r) return html;
    let id = 0;
    const body = html.slice(r[0], r[1]).replace(/<a href="([^"#]+\.md)#q(\d+)[^"]*"[^>]*>[\s\S]*?<\/a>/g, (a, href, n) => {
      const file = answerFile(ctx.dir, decodeURIComponent(href), ctx.readFile), page = ctx.readFile(file);
      const sec = page && questionSection(page, n);
      if (!sec) return a;
      const f = fields(sec), k = ++id, path = require("path");
      // the link and the popup's Open link go to the file that was read, from a worktree too
      const rel = encodeURI(path.relative(ctx.dir, file).split(path.sep).join("/"));
      a = a.split(`"${href}`).join(`"${rel}`);
      // the answer page's own links are relative to its folder: make them relative to the index's
      const full = rebase(ctx.render(page), path.dirname(file), ctx.dir).replace(new RegExp(`<h2([^>]*)>(\\s*Q${n}\\.)`), `<h2$1 data-pp-q="${n}">$2`);
      return `<span class="pp-q" data-pp-id="${k}">${a}<div class="pp-full" hidden data-pp-id="${k}" data-pp-q="${n}" data-pp-href="${esc(rel)}#q${n}">${toggle(k, file, n, f)}${full}</div></span>`;
    });
    return html.slice(0, r[0]) + body + html.slice(r[1]);
  }

  // Each relative link of html, written from the folder from, made relative to the folder to.
  function rebase(html, from, to) {
    if (from === to) return html;
    const path = require("path");
    return html.replace(/<a\s[^>]*>/gi, tag => tag.replace(/(\s(?:data-)?href=")(?![a-z][a-z0-9+.-]*:|#|\/)([^"#]+)([^"]*)"/gi, (m, attr, href, hash) =>
      `${attr}${encodeURI(path.relative(to, path.resolve(from, decodeURIComponent(href))).split(path.sep).join("/"))}${hash}"`));
  }

  // Every other relative link that is missing from a worktree, but there from the main checkout, goes there.
  function worktreeLinks(html, ctx) {
    if (!ctx.dir || !/\/\.claude\/worktrees\//.test(ctx.dir)) return html;
    const path = require("path");
    // VS Code's preview opens a link by its data-href when it has one, so both attributes change.
    return html.replace(/<a\s[^>]*>/gi, tag => tag.replace(/(\s(?:data-)?href=")(?![a-z][a-z0-9+.-]*:|#|\/)([^"#]+)([^"]*)"/gi, (m, attr, href, hash) => {
      const file = answerFile(ctx.dir, decodeURIComponent(href), ctx.readFile);
      return ctx.readFile(file) ? `${attr}${encodeURI(path.relative(ctx.dir, file).split(path.sep).join("/"))}${hash}"` : m;
    }));
  }

  // Each research question gets its mark as its bullet, in place of the word open or answered. A deferred
  // item starts with the warning sign, or the old [defer]. Runs before questions(), while each item is one line.
  function marks(html, ctx) {
    let r = range(html, "Research questions", "h2");
    if (r) html = html.slice(0, r[0]) + html.slice(r[0], r[1]).replace(/<li([^>]*)>(\s*(?:<p[^>]*>)?\s*)([\s\S]*?)<\/li>/g, (m, attrs, lead, rest) => {
      const deferred = /^(?:\u26A0\uFE0F?|\[defer\])\s*/.test(rest);
      rest = rest.replace(/^(?:\u26A0\uFE0F?|\[defer\])\s*/, "");
      const status = (rest.match(/^(open|answered)\b/) || [])[1] || "open";
      rest = rest.replace(/^(open|answered)\b\s*/, "");
      const link = rest.match(/<a href="([^"#]+\.md)#q(\d+)/);
      const page = link && ctx.dir && ctx.readFile(answerFile(ctx.dir, decodeURIComponent(link[1]), ctx.readFile));
      const sec = page && questionSection(page, link[2]), f = sec ? fields(sec) : { feedback: "not_checked", reason: "" };
      const e = deferred ? DEFER : markOf(status, f.feedback);
      const first = f.feedback === "disagree" ? "You disagree: " + (f.reason || "n/a") : "";
      return bullet(attrs, e, ` data-pp-status="${deferred ? "deferred" : status}"`) + legend(ROWS, e, first) + lead + rest + "</li>";
    }) + html.slice(r[1]);
    // An open question keeps its number, so the user can answer by number.
    r = range(html, "Open questions", "h2");
    let n = 0;
    if (r) html = html.slice(0, r[0]) + html.slice(r[0], r[1]).replace(/<li([^>]*)>(\s*(?:<p[^>]*>)?\s*)(\u26A0\uFE0F?|\[defer\])?\s*/g, (m, attrs, lead, mark) => {
      n++;
      return mark ? `<li${attrs} style="list-style-type: '${n}. ${DEFER} '" data-legend="">${legend([[DEFER, "deferred: left for later, spec and p-design go on without it"]], DEFER)}${lead}` : m;
    }) + html.slice(r[1]);
    return html;
  }

  const apply = (html, ctx = {}) => worktreeLinks(questions(marks(foldParts(html, ctx.statesOnly), ctx), ctx), ctx);

  // ---- the page: popup, toggle, marks

  function preview() {
    if (typeof document === "undefined" || document.__ppInit) return;
    document.__ppInit = true;
    let overlay, ask;
    const closeAsk = () => { ask && ask.remove(); ask = null; };
    const close = () => { overlay && overlay.remove(); overlay = null; };
    const el = (tag, cls, text) => Object.assign(document.createElement(tag), { className: cls, textContent: text || "" });

    // Update every copy of one toggle (the page's and the popup's), and the mark of the question.
    function show(id, value, reason) {
      document.querySelectorAll(`.pp-fb[data-pp-id="${id}"]`).forEach(box => {
        // the open popup is not rendered again, so its disagree link gets the reason the file now holds
        const d = box.querySelector('[data-value="disagree"]'), was = box.querySelector(".pp-on")?.dataset.value;
        if (value === "disagree") d.title = reason;
        else if (d.title && was !== value) d.title = keptReason(d.title, value, now());
        box.querySelectorAll(".pp-pick").forEach(a => a.classList.toggle("pp-on", a.dataset.value === value));
      });
      // The bullet of an answered question shows the new mark, and the legend marks its row.
      const li = document.querySelector(`.pp-q[data-pp-id="${id}"]`)?.closest("li");
      if (!li || li.dataset.ppStatus === "deferred") return;
      const e = markOf(li.dataset.ppStatus, value);
      li.style.listStyleType = `'${e} '`;
      li.querySelectorAll(":scope > .eb-legend > .eb-row").forEach(r => r.classList.toggle("eb-on", r.textContent.startsWith(e)));
      // the User feedback line in the page text, in the hidden copy and in an open popup
      document.querySelectorAll(`.pp-full[data-pp-id="${id}"], .pp-overlay .pp-modal`).forEach(root => {
        if (root.classList.contains("pp-modal") && root.querySelector(".pp-fb")?.dataset.ppId !== String(id)) return;
        const n = root.dataset.ppQ || root.querySelector("[data-pp-q]")?.dataset.ppQ;
        for (let e = root.querySelector(`h2[data-pp-q="${n}"]`)?.nextElementSibling; e && e.tagName !== "H2"; e = e.nextElementSibling)
          e.querySelectorAll("li strong").forEach(b => { if (b.textContent.trim() === "User feedback:" && b.nextSibling) b.nextSibling.textContent = " " + value; });
      });
      const box = li.querySelector(":scope > .eb-legend");
      box && box.querySelector(".eb-first")?.remove();
      if (box && value === "disagree") box.prepend(el("span", "eb-first", "You disagree: " + reason));
    }

    // On window, in the capture phase: the preview's own link handler is on document, and would open the file first.
    window.addEventListener("click", e => {
      const t = e.target, a = t.closest && t.closest(".pp-q > a");
      if (a) {   // a click opens the popup, at the question
        e.preventDefault(); e.stopImmediatePropagation(); close();
        // by id: a loose list puts the div outside its <p>, and so outside .pp-q
        const full = document.querySelector(`.pp-full[data-pp-id="${a.parentElement.dataset.ppId}"]`);
        if (!full) return;
        overlay = el("div", "pp-overlay");
        const modal = el("div", "pp-modal"), x = el("button", "pp-close", "Close");
        const go = Object.assign(el("a", "pp-open", "Open the page"), { href: full.dataset.ppHref }), head = el("div", "pp-head");
        modal.insertAdjacentHTML("beforeend", full.innerHTML);
        head.append(go, modal.querySelector(".pp-fb") || "", x);
        modal.prepend(head);
        overlay.append(modal);
        document.body.append(overlay);
        const target = modal.querySelector(`[data-pp-q="${full.dataset.ppQ}"]`);
        if (target) modal.scrollTop = target.offsetTop;
        return;
      }
      // Send goes on to VS Code's own link handler: without it, the webview itself goes to the link
      if (ask && ask.contains(t)) { if (!t.classList.contains("pp-send")) e.stopImmediatePropagation(); }
      else if (overlay && (t === overlay || t.classList.contains("pp-close"))) return close();
      if (t.classList && t.classList.contains("pp-open")) close();   // the preview's handler opens the page
      const pick = t.closest && t.closest(".pp-fb .pp-pick");
      if (pick) {
        const box = pick.parentElement, id = box.dataset.ppId;
        if (pick.dataset.value !== "disagree") return show(id, pick.dataset.value, "");   // the link writes
        e.preventDefault(); e.stopImmediatePropagation();   // a disagree writes only after its reason
        // a second popup on top, with a text box for the reason
        ask && ask.remove();
        ask = el("div", "pp-overlay pp-ask-overlay");
        const dlg = el("div", "pp-ask"), input = Object.assign(el("textarea", "pp-reason"), { placeholder: "Why do you disagree?", rows: 6 });
        const row = el("div", "pp-ask-row");
        // Send is a real link, as agree is. VS Code's webview follows only a link the user clicks or presses
        // Enter on: a link the script clicks sent the whole preview to a blank page.
        const base = box.querySelector('[data-value="disagree"]').href;
        const send = Object.assign(el("a", "pp-send", "Send"), { href: base, title: "Click, or press Cmd+Enter then Enter" });
        input.addEventListener("input", () => { send.href = base + "&reason=" + enc(input.value.trim()); });
        row.append(el("button", "pp-cancel", "Cancel  Esc"), send);
        dlg.append(el("div", "pp-ask-title", "Disagree: your reason"), input, row);
        ask.append(dlg); ask.ppBox = box;
        document.body.append(ask);
        // the last reason, to edit, with the cursor on a new line after a closing ===
        const last = box.querySelector('[data-value="disagree"]').title || "";
        input.value = last.endsWith("===") ? last + "\n" : last;
        input.dispatchEvent(new Event("input"));
        input.focus();
        input.selectionStart = input.selectionEnd = input.value.length;
        return;
      }
      if (!ask || !ask.contains(t)) return;
      if (t === ask || t.classList.contains("pp-cancel")) return closeAsk();
      if (t.classList.contains("pp-send")) {   // the link itself writes; this only updates the page
        const box = ask.ppBox, reason = ask.querySelector("textarea").value.trim();
        if (!reason) { e.preventDefault(); return ask.querySelector("textarea").focus(); }
        show(box.dataset.ppId, "disagree", reason);
        setTimeout(closeAsk);   // after VS Code's own handler has seen the click
      }
    }, true);
    // On window, in the capture phase, before VS Code's own keys. Esc closes. Cmd+Enter moves to Send, and
    // Enter there sends: a script cannot send for the user. Enter alone is a new line in the text box.
    window.addEventListener("keydown", e => {
      if (e.key === "Escape" && (ask || overlay)) { e.preventDefault(); e.stopImmediatePropagation(); return ask ? closeAsk() : close(); }
      if (e.key === "Enter" && (e.metaKey || e.ctrlKey) && ask) { e.preventDefault(); e.stopImmediatePropagation(); ask.querySelector(".pp-send").focus(); }
    }, true);
  }

  return { apply, foldParts, questions, setFeedback, questionSection, feedbackUri, parseFeedbackUri, preview };
});
