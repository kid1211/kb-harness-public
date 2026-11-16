/* extension.js - Markdown Diff. A diff of a .md file opens as rendered Markdown, with the
 * changes marked by markdown-diff.js, the whole file shown, in the same tab group.
 * A strip on the right marks where each change is. "Markdown Diff: Open" shows the open .md
 * file against HEAD. The page uses the stylesheets of VS Code's own Markdown preview.
 * The normal preview shows YAML front matter as a table, as the diff does (extendMarkdownIt).
 * Cmd+Shift+C copies @<full path>#L12-20 of the selected lines, in a text editor, a text diff,
 * the Markdown Diff and the Markdown preview (plans/vscode/components/code-reference).
 */
const vscode = require("vscode");
const { execFile, execFileSync } = require("child_process");
const path = require("path");
const { resolve } = require("./import-graph.js");
const EmojiBullets = require("./emoji-bullets.js");
const { frontmatter } = require("./markdown-diff.js");
const CR = require("./code-reference.js");
const PP = require("./plan-preview.js");
const fs = require("fs");
// id-hover: the term cards and ID cards of a reply, in the preview and the diff (preview-cards).
// id-core.js is the copy of the mod's core.mjs that build.sh makes. If it fails to load, no card.
let IdCore = null, IdCards = null;
try { IdCore = require("./id-core.js"); IdCards = require("./id-cards.js"); } catch { IdCore = IdCards = null; }
// The harness root of a file: the folder above its nearest .claude/skills, with the link followed,
// as the mod finds it from a KB. The levels come from the mod's git command.
const idIo = {
  readFile: p => { try { return fs.readFileSync(p, "utf8"); } catch { return null; } },
  listFiles: root => { try { return execFileSync("git", ["-C", root, "ls-files", "--cached", "--others", "--exclude-standard", "plans"], { encoding: "utf8", timeout: 2000 }); } catch { return ""; } },
  root: file => {
    for (let dir = path.dirname(file); dir !== path.dirname(dir); dir = path.dirname(dir)) {
      const skills = path.join(dir, ".claude", "skills");
      if (fs.existsSync(path.join(skills, "id-hover"))) return path.dirname(path.dirname(fs.realpathSync(skills)));
    }
    return null;
  },
  now: () => Date.now(),
};
const idCards = (file, text) => IdCards && file ? IdCards.context(IdCore, file, text, idIo) : null;
// Each Cmd+Shift+C logs its steps here, to the window's log folder, so a failed copy shows where it stopped.
let log = { info() {} };

// In the Markdown preview, a ```graph block with only `import-graph: <path>` gets the graph
// text of that file, before preview.js draws it (plans/draw-graph R18). A failed import shows
// why. The preview re-renders on an edit of the page, not of the imported file.
function extendMarkdownIt(md) {
  const fence = md.renderer.rules.fence;
  md.renderer.rules.fence = (tokens, idx, opts, env, self) => {
    const t = tokens[idx], doc = env?.currentDocument;
    if (t.info.trim() === "graph" && doc?.fsPath) {
      const g = resolve(t.content, doc.fsPath);
      if (g instanceof Error) return `<pre class="dg-err">${md.utils.escapeHtml(g.message)}</pre>\n`;
      if (!g.trim()) return `<p><em>${md.utils.escapeHtml(t.content.trim())}: the graph is blank.</em></p>\n`;
      t.content = g + "\n";
    }
    return fence(tokens, idx, opts, env, self);
  };
  // emoji-bullets: an emoji at the start of a list item is its bullet, with the status legend on hover.
  const render = md.renderer.render.bind(md.renderer);
  // plan-preview: folded parts, the states-only view and the research popups. The setting is
  // read at each render. A nested render of an answer page has no currentDocument, so it skips this.
  md.renderer.render = (tokens, opts, env) => {
    let html = render(tokens, opts, env);
    const doc = env?.currentDocument;
    if (doc?.fsPath) html = PP.apply(html, {
      dir: path.dirname(doc.fsPath), render: s => md.render(s, {}), statesOnly: vscode.workspace.getConfiguration("planPreview").get("statesOnly", false),
      readFile: p => { try { return fs.readFileSync(p, "utf8"); } catch { return null; } },
    });
    if (doc?.fsPath && IdCards) html = IdCards.apply(html, idCards(doc.fsPath, html), IdCore);
    return EmojiBullets.apply(html);
  };
  // The preview's markdown-it gets the text with its front matter already a table.
  const parse = md.parse.bind(md);
  md.parse = (src, env) => parse(frontmatter(src), env);
  return md;
}

const SCRIPTS = ["marked.min.js", "diff.min.js", "markdown-diff.js", "emoji-bullets.js", "preview.bundle.js", "id-core.js", "id-cards.js", "diff-view.js"];
// In the order the preview loads them: VS Code's, then this extension's previewStyles.
const STYLES = ["palette.css", "preview.css", "emoji-bullets.css", "markdown-diff.css", "diff-view.css", "id-cards.css"];

function activate(ctx) {
  log = vscode.window.createOutputChannel("TalkToClaude", { log: true });
  const preview = vscode.extensions.getExtension("vscode.markdown-language-features").extensionUri;
  const panels = new Map();   // one tab per file: a second diff of it replaces the first
  const open = async (oldUri, newUri, column, preserveFocus) => {
    panels.get(newUri.toString())?.dispose();
    const panel = vscode.window.createWebviewPanel("markdownDiff", path.basename(newUri.path) + " (Markdown Diff)",
      { viewColumn: column || vscode.ViewColumn.Active, preserveFocus }, { enableScripts: true, localResourceRoots: [ctx.extensionUri, preview] });
    const uri = (root, f) => panel.webview.asWebviewUri(vscode.Uri.joinPath(root, f));
    const css = [uri(preview, "media/markdown.css"), uri(preview, "media/highlight.css"), ...STYLES.map(f => uri(ctx.extensionUri, f))];
    // The same font settings the preview passes to markdown.css.
    const md = vscode.workspace.getConfiguration("markdown.preview", newUri);
    panel.webview.html = `<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${panel.webview.cspSource} https: data:; style-src ${panel.webview.cspSource} 'unsafe-inline'; script-src ${panel.webview.cspSource};">
${css.map(h => `<link rel="stylesheet" href="${h}">`).join("\n")}
</head><body class="wordWrap" style="--markdown-font-family: ${md.get("fontFamily")}; --markdown-font-size: ${md.get("fontSize")}px; --markdown-line-height: ${md.get("lineHeight")};">
<div id="md"></div><div id="ruler"></div>
${SCRIPTS.map(f => `<script src="${uri(ctx.extensionUri, f)}"></script>`).join("")}</body></html>`;
    // The old side is read once. The new side is sent again on each edit. No old side: all added.
    const oldText = oldUri ? read(oldUri) : Promise.resolve("");
    const send = async () => {
      const o = await oldText, n = await read(newUri);
      panel.webview.postMessage({ old: o, new: n, cards: IdCards && IdCards.pack(idCards(newUri.fsPath, o + "\n" + n)) });
    };
    panel.resend = send;
    panel.webview.onDidReceiveMessage(m => {
      if (m === "ready") send();
      else if (m?.type === "ref") panel.onRef?.(m.lines);
      else if (m?.type === "sel") { panel.sel = m.lines; showHint(m); }
    });
    panel.onDidChangeViewState(() => showHint());   // showHint is set later in activate
    panel.newUri = newUri;
    const sub = vscode.workspace.onDidChangeTextDocument(e => e.document.uri.toString() === newUri.toString() && send());
    panels.set(newUri.toString(), panel);
    panel.onDidDispose(() => { sub.dispose(); if (panels.get(newUri.toString()) === panel) panels.delete(newUri.toString()); });
  };

  // plan-preview: a click on a feedback link in the preview comes here (R3). Only a Q<n> section of a .staging.md page changes.
  ctx.subscriptions.push(vscode.window.registerUriHandler({ handleUri: async uri => {
    const f = uri.path === "/feedback" && PP.parseFeedbackUri(uri.query);
    if (!f || !f.file.endsWith(".staging.md")) return;   // only a KB staging page, Claude's area
    const doc = await vscode.workspace.openTextDocument(vscode.Uri.file(f.file));
    if (doc.isDirty) return vscode.window.showWarningMessage(`Save or undo your edits in ${doc.fileName} first.`);
    const text = PP.setFeedback(doc.getText(), f.q, f.value, f.reason);
    if (text === doc.getText()) return;
    const edit = new vscode.WorkspaceEdit();
    edit.replace(doc.uri, new vscode.Range(0, 0, doc.lineCount, 0), text);
    if (await vscode.workspace.applyEdit(edit)) await doc.save();
  } }));
  // id-hover: a save of a plan file draws the previews and the diffs again, so a card shows the text on disk.
  ctx.subscriptions.push(vscode.workspace.onDidSaveTextDocument(d => {
    if (!/\/plans\//.test(d.uri.fsPath)) return;
    IdCards?.forget(idIo);
    vscode.commands.executeCommand("markdown.preview.refresh");
    panels.forEach(p => p.resend?.());
  }));
  // plan-preview: a change of the setting draws the previews again.
  ctx.subscriptions.push(vscode.workspace.onDidChangeConfiguration(e =>
    e.affectsConfiguration("planPreview") && vscode.commands.executeCommand("markdown.preview.refresh")));

  ctx.subscriptions.push(vscode.commands.registerCommand("markdownDiff.open", async uri => {
    uri = uri?.resourceUri || uri || vscode.window.activeTextEditor?.document.uri || activeTabUri();
    if (!uri || !uri.path.endsWith(".md")) return vscode.window.showInformationMessage("Open a .md file first.");
    await open(uri.with({ scheme: "git-head" }), uri);
  }));

  // HEAD's text of a file, through git.
  ctx.subscriptions.push(vscode.workspace.registerTextDocumentContentProvider("git-head", {
    provideTextDocumentContent: uri => new Promise(ok => execFile("git", ["-C", path.dirname(uri.fsPath), "show", "HEAD:./" + path.basename(uri.fsPath)],
      { maxBuffer: 1 << 26 }, (err, out) => ok(err ? "" : out))),   // not in HEAD: an empty old side, all added
  }));

  // A diff of a .md file, such as a click in Source Control, opens as the rendered diff instead.
  // With "*.md" set to open in the preview, a diff shows two previews, and the API gives its
  // tab no input: the user setting "git:/**/*.md": "default" keeps a git diff a text diff.
  // A diff opened in preview mode replaces the preview tab, so it comes as a changed tab, not
  // an opened one. A diff opened before this extension started is swapped at the start.
  // A file a commit added has no old side, so a click on it in the Graph opens it alone, as a
  // git: text tab. It is swapped too, with an empty old side, if the commit's parent lacks it.
  // Claude Code's diff of a proposed edit (/ide) must stay open: closing it rejects the edit.
  // Its Markdown Diff opens beside it instead, and closes with it.
  const claude = u => u.scheme.startsWith("_claude");
  const swap = tabs => tabs.forEach(async tab => {
    const i = tab.input;
    let pair;
    if (i instanceof vscode.TabInputTextDiff && i.modified.path.endsWith(".md") && claude(i.modified)) {
      if (!panels.has(i.modified.toString())) open(i.original, i.modified, vscode.ViewColumn.Beside, true);
      return;
    }
    if (i instanceof vscode.TabInputTextDiff && i.modified.path.endsWith(".md") && ["file", "git"].includes(i.modified.scheme)) pair = [i.original, i.modified];
    else if (i instanceof vscode.TabInputText && i.uri.scheme === "git" && i.uri.path.endsWith(".md") && await addedIn(i.uri)) pair = [null, i.uri];
    else return;
    vscode.window.tabGroups.close(tab).then(ok => ok && open(...pair, tab.group.viewColumn), () => {});   // already closed
  });
  ctx.subscriptions.push(vscode.window.tabGroups.onDidChangeTabs(e => {
    e.closed.forEach(tab => tab.input instanceof vscode.TabInputTextDiff && claude(tab.input.modified) &&
      panels.get(tab.input.modified.toString())?.dispose());
    swap([...e.opened, ...e.changed]);
  }));
  swap(vscode.window.tabGroups.all.flatMap(g => g.tabs));

  // R11: the status bar says what to do next, in the four places only.
  // A press shows its result in the same line for 6 seconds (R10), then the hint comes back.
  const item = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, -100);
  let noteUntil = 0;
  const showHint = e => {
    if (e?.selections || e?.type === "sel") noteUntil = 0;   // a new selection ends the note
    if (Date.now() < noteUntil) return;
    const diff = [...panels.values()].find(p => p.active);
    const input = vscode.window.tabGroups.activeTabGroup.activeTab?.input;
    const ed = vscode.window.activeTextEditor;
    const lines = diff ? diff.sel ?? null
      : /markdown\.preview/.test(input?.viewType || "") ? undefined
      : (input instanceof vscode.TabInputText || input instanceof vscode.TabInputTextDiff) && ed ? CR.editorLines(ed.selections)
      : false;
    if (lines === false) return item.hide();
    item.text = CR.hint(lines);
    item.show();
  };
  ctx.subscriptions.push(item, vscode.window.onDidChangeTextEditorSelection(showHint),
    vscode.window.onDidChangeActiveTextEditor(showHint), vscode.window.tabGroups.onDidChangeTabs(showHint));
  showHint();

  ctx.subscriptions.push(vscode.commands.registerCommand("codeReference.copy", async () => {
    log.info("press; tab:", vscode.window.tabGroups.activeTabGroup.activeTab?.input?.constructor?.name, vscode.window.tabGroups.activeTabGroup.activeTab?.input?.viewType || "");
    const found = await selected([...panels.values()].find(p => p.active));
    log.info("found:", JSON.stringify(found && { uri: found.uri?.toString(), lines: found.lines }));
    if (found === undefined) return;   // not one of the four places
    const { uri, lines } = found || {};
    const ref = uri ? CR.refOf(uri) : "";
    if (lines) await vscode.env.clipboard.writeText(CR.reference(uri.fsPath, lines, ref));
    item.text = CR.note(uri && path.basename(uri.fsPath), lines, ref);
    item.show();
    if (lines) { noteUntil = Date.now() + 6000; setTimeout(showHint, 6000); }
  }));
  return { extendMarkdownIt };
}

// The selection of the active place as { uri, lines }, with lines null when nothing is
// selected. undefined: the active tab is none of the four places.
async function selected(diff) {
  if (diff) {
    const lines = await new Promise(ok => { diff.onRef = ok; diff.webview.postMessage({ type: "ref" }); setTimeout(ok, 1000, null); });
    return { uri: diff.newUri, lines };
  }
  const input = vscode.window.tabGroups.activeTabGroup.activeTab?.input;
  // The preview beside an editor is a webview, a .md opened as a preview is a custom editor.
  if (/markdown\.preview/.test(input?.viewType || "")) return previewSelection();
  const ed = vscode.window.activeTextEditor;
  if (!ed) return undefined;
  return { uri: ed.document.uri, lines: CR.editorLines(ed.selections) };
}

// The preview gives no message channel: run a copy in it, and its script answers in the
// clipboard (code-reference.js). The user's clipboard text is put back. ponytail: text only, an
// image on the clipboard is lost.
async function previewSelection() {
  const clip = vscode.env.clipboard, before = await clip.readText(), wait = CR.MARK + "wait";
  await clip.writeText(wait);
  await vscode.commands.executeCommand("editor.action.clipboardCopyAction");
  let got = wait;
  for (let i = 0; i < 40 && got === wait; i++) { await new Promise(ok => setTimeout(ok, 25)); got = await clip.readText(); }
  await clip.writeText(before);
  log.info("preview answered:", got === wait ? "(no answer)" : got);
  const m = CR.parseMark(got);
  if (!m) return null;
  const uri = vscode.Uri.parse(m.uri), doc = await vscode.workspace.openTextDocument(uri);
  const end = Math.min(m.lines.end, doc.lineCount);
  return { uri, lines: CR.trimEnd({ start: m.lines.start, end }, n => doc.lineAt(n - 1).text) };
}

// Did the commit of this git: URI add the file? True when its first parent has no such file.
function addedIn(uri) {
  let q;
  try { q = JSON.parse(uri.query); } catch { return Promise.resolve(false); }
  if (!q.ref || /^(~|HEAD$|:)/.test(q.ref)) return Promise.resolve(false);   // the index or HEAD, not a commit of the Graph
  return new Promise(ok => execFile("git", ["-C", path.dirname(q.path), "cat-file", "-e", `${q.ref}^:./${path.basename(q.path)}`],
    err => ok(!!err)));
}

async function read(uri) {
  return (await vscode.workspace.openTextDocument(uri)).getText();
}

function activeTabUri() {
  const i = vscode.window.tabGroups.activeTabGroup.activeTab?.input;
  return i?.uri;
}

module.exports = { activate };
