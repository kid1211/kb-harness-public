// Run: node --test .claude/lib/markdown-diff/tests/markdown-diff.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { marked } = require("marked");
const Diff = require("diff");
const { render, frontmatter } = require("../markdown-diff.js");

const md = (a, b) => render(a, b, { marked, Diff });

test("an unchanged file renders with no marks", () => {
  const out = md("# T\n\nSame text.\n", "# T\n\nSame text.\n");
  assert.match(out, /<h1>T<\/h1>/);
  assert.doesNotMatch(out, /md-(ins|del|chg)|<ins>|<del>/);
});

test("an added and a removed block are wrapped whole", () => {
  const out = md("# T\n\nGone paragraph.\n", "# T\n\n## New heading\n");
  assert.match(out, /<div class="md-del"><p>Gone paragraph.<\/p>/);
  assert.match(out, /<div class="md-ins"><h2>New heading<\/h2>/);
});

test("a changed paragraph marks only the changed words, inside rendered Markdown", () => {
  const out = md("The **quick** fox jumps.\n", "The **quick** red fox leaps.\n");
  assert.match(out, /md-chg/);
  assert.match(out, /<strong>quick<\/strong>/);
  assert.match(out, /<ins>red <\/ins>|<ins>red<\/ins>/);
  assert.match(out, /<del>jumps<\/del><ins>leaps<\/ins>\./);
  assert.doesNotMatch(out, /<ins>[^<]*<strong/);   // a tag never sits inside <ins>
});

test("added punctuation marks only the punctuation, not the word beside it", () => {
  const out = md("Its parts are read-aloud and click-copy, all shared.\n", "Its parts are read-aloud, click-copy and code-review, all shared.\n");
  assert.doesNotMatch(out, /<del>read/);
  assert.match(out, /read-aloud<ins>,<\/ins>/);
});

test("a changed list item keeps the list and marks the word", () => {
  const out = md("- one\n- two\n", "- one\n- three\n");
  assert.match(out, /<ul>/);
  assert.match(out, /<del>two<\/del>/);
  assert.match(out, /<ins>three<\/ins>/);
});

test("a changed code block (a graph too) shows old as removed and new as added", () => {
  const out = md("```graph\na -> b\n```\n", "```graph\na -> c\n```\n");
  assert.match(out, /md-del"><pre><code class="language-graph">a -&gt; b/);
  assert.match(out, /md-ins"><pre><code class="language-graph">a -&gt; c/);
});

test("a rewritten paragraph is a removal and an addition, not a word soup", () => {
  const out = md("Completely different words here.\n", "Nothing alike at all, honestly.\n");
  assert.match(out, /md-del/);
  assert.match(out, /md-ins/);
  assert.doesNotMatch(out, /md-chg/);
});

test("a new file is all added, a deleted file all removed", () => {
  assert.match(md("", "# New\n"), /^<div class="md-ins"><h1>New/);
  assert.match(md("# Old\n", ""), /^<div class="md-del"><h1>Old/);
});

test("reference links still resolve inside one block", () => {
  const out = md("", "See [the doc][d].\n\n[d]: https://example.com\n");
  assert.match(out, /href="https:\/\/example.com"/);
});

test("front matter renders as a key | value table, a nested value as code lines", () => {
  const fm = "---\nname: p-x\ndescription: Reads `plans/`.\nhooks:\n  PostToolUse:\n    - matcher: \"Write|Edit\"\n---\n# P-x\n";
  assert.doesNotMatch(frontmatter("# No front matter\n"), /Key/);
  const out = md(fm, fm.replace("p-x", "p-y"));
  assert.match(out, /<table>/);
  assert.match(out, /<td>description<\/td>\s*<td>Reads <code>plans\/<\/code>\.<\/td>/);
  assert.match(out, /<code>\u00a0\u00a0\u00a0\u00a0- matcher: &quot;Write\|Edit&quot;<\/code>/);
  assert.match(out, /<del>p<\/del>|<ins>y<\/ins>/);   // the changed row is marked inside the table
  assert.match(out, /<h1>P-x<\/h1>/);
});

// plans/vscode/components/code-reference R4: each block knows its lines in the new file.
test("with lines, each block carries its lines in the new file, and a removed block the next line", () => {
  const out = render("# T\n\nGone.\n\nKeep\nthis.\n", "# T\n\nKeep\nthis.\n\n- a\n- b\n", { marked, Diff, lines: true });
  assert.match(out, /<h1 data-src-lines="1-1">T<\/h1>/);
  assert.match(out, /<div class="md-del" data-src-lines="3-3"><p>Gone/);
  assert.match(out, /<p data-src-lines="3-4">Keep/);
  assert.match(out, /<div class="md-ins" data-src-lines="6-7"><ul>/);
});

test("with lines, front matter is the whole front matter, and the lines after it match the file", () => {
  const src = "---\ntitle: X\ntags: a\n---\n\n# H\n";
  const out = render(src, src, { marked, Diff, lines: true });
  assert.match(out, /<table data-src-lines="1-4">/);
  assert.match(out, /<h1 data-src-lines="6-6">H<\/h1>/);
});
