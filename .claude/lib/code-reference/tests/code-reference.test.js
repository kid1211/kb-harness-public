// Run: node --test .claude/lib/code-reference/tests/code-reference.test.js
// One test per place (plans/vscode/components/code-reference R2). The Markdown Diff's
// lines are tested in markdown-diff.test.js. The key and the clipboard need VS Code: not tested here.
const test = require("node:test");
const assert = require("node:assert/strict");
const CR = require("../code-reference.js");

const sel = (sl, sc, el, ec) => ({ start: { line: sl, character: sc }, end: { line: el, character: ec }, isEmpty: sl === el && sc === ec });

test("text editor: the selected lines, 1-based, as @path#L", () => {
  const l = CR.editorLines([sel(11, 2, 19, 5)]);
  assert.deepEqual(l, { start: 12, end: 20 });
  assert.equal(CR.reference("/r/a.md", l, ""), "@/r/a.md#L12-20");
  assert.equal(CR.reference("/r/a.md", { start: 3, end: 3 }, ""), "@/r/a.md#L3");
});

test("text editor: a selection that ends at the start of a line does not take that line", () => {
  assert.deepEqual(CR.editorLines([sel(4, 0, 6, 0)]), { start: 5, end: 6 });
});

test("nothing selected: null, and the note says how", () => {
  assert.equal(CR.editorLines([sel(4, 3, 4, 3)]), null);
  assert.equal(CR.note("a.md", null, ""), "TalkToClaude: select text, then press Cmd+Shift+C.");
});

test("text diff: a side that is a git version names it, a file names none", () => {
  const git = ref => ({ scheme: "git", query: JSON.stringify({ path: "/r/a.md", ref }) });
  assert.equal(CR.refOf({ scheme: "file" }), "");
  assert.equal(CR.refOf(git("HEAD")), "HEAD");
  assert.equal(CR.refOf(git("~")), "the index");
  assert.equal(CR.refOf(git("5f5664121b5ec474fd506430e65cdab808cc3844")), "5f56641");
  assert.equal(CR.refOf({ scheme: "git-head" }), "HEAD");
  assert.equal(CR.reference("/r/a.md", { start: 2, end: 4 }, "HEAD"), "@/r/a.md (version at HEAD, L2-4)");
});

test("the live hint: lines selected, or nothing selected, one wording for every place", () => {
  assert.equal(CR.hint({ start: 12, end: 20 }), "TalkToClaude: L12-20 selected. Press Cmd+Shift+C.");
  assert.equal(CR.hint(null), "TalkToClaude: select text, then press Cmd+Shift+C.");
  assert.equal(CR.hint(undefined), "TalkToClaude: select text, then press Cmd+Shift+C.");
});

test("the note names the file and the lines", () => {
  assert.equal(CR.note("req.md", { start: 12, end: 20 }, ""), "TalkToClaude: copied req.md#L12-20. Switch to Claude and press Cmd+V.");
});

test("Markdown preview: from the start block to the line before the next block, nested blocks too", () => {
  const b = (line, kids = []) => ({ line, contains: x => kids.includes(x) });
  const li1 = b(5), li2 = b(6), ul = b(5, [li1, li2]), h = b(0), p = b(2), after = b(9);
  const all = [h, p, ul, li1, li2, after];
  assert.deepEqual(CR.previewLines(p, p, all), { start: 3, end: 5 });       // to the line before the list
  assert.deepEqual(CR.previewLines(h, li1, all), { start: 1, end: 6 });     // ends before the next item
  assert.deepEqual(CR.previewLines(ul, ul, all), { start: 6, end: 9 });     // the whole list
  assert.deepEqual(CR.previewLines(after, after, all), { start: 10, end: 10 });
});

test("Markdown preview: the page's answer in the clipboard", () => {
  assert.deepEqual(CR.parseMark(CR.MARK + "file:///r/a.md#3-5"), { uri: "file:///r/a.md", lines: { start: 3, end: 5 } });
  assert.equal(CR.parseMark(CR.MARK + "none"), null);
  assert.equal(CR.parseMark("my clipboard"), undefined);
});

test("blank lines at the end of a range are dropped", () => {
  const text = ["", "a", "b", "", ""];   // 1-based: line 1 is "a"
  assert.deepEqual(CR.trimEnd({ start: 1, end: 4 }, n => text[n]), { start: 1, end: 2 });
});
