// Run: node --test .claude/lib/plan-preview/tests/plan-preview.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { marked } = require("marked");
const PP = require("../plan-preview.js");

const DESIGN = `# D

## State deep dive

### Ready

Text of the state.

- **Guard:** the guard text.
- **Invariants:** \`inv_a\`, \`inv_b\`.
- **Effect:** the effect text.
  - a nested line

### Done

- **Invariants:** \`inv_c\`.

## Coverage

- **Guard:** outside the deep dive.
`;

const ANSWER = `# Answers

## Q1. Can a click write?

- **Status:** yes
- **Confidence:** 4. Read from source.
- **Sources:** [1]
- **User feedback:** not_checked
- **Disagree reason:**

Body of one.

## Q2. How does it open?

- **Status:** done
- **Sources:** [2]
- **User feedback:** disagree
- **Disagree reason:** too broad

## Sources

1. x
`;

const INDEX = `# P

## Research questions

1. answered [Can a click write?](a.staging.md#q1-can-a-click-write)
2. open [How does it open?](a.staging.md#q2-how-does-it-open)
`;

const html = (md, ctx) => PP.apply(marked.parse(md), ctx);
const ctx = (extra = {}) => ({ dir: "/kb", readFile: p => (p === "/kb/a.staging.md" ? ANSWER : null), render: marked.parse, ...extra });

// ---- R1: folded parts

test("R1 Reading effect: Guard, Invariants and Effect fold, closed, inside the deep dive only", () => {
  const out = html(DESIGN);
  assert.equal(out.match(/<details class="pp-part">/g).length, 4);
  assert.doesNotMatch(out, /<details[^>]* open/);
  assert.match(out, /<summary><strong>Guard:<\/strong><\/summary> the guard text\./);
  assert.match(out, /<li><strong>Guard:<\/strong> outside the deep dive\.<\/li>/);
  assert.match(out, /<p>Text of the state\.<\/p>/);
});

test("R1 Part open effect: a part with a nested list stays whole in its fold", () => {
  const out = html(DESIGN);
  const eff = out.match(/<details class="pp-part"><summary><strong>Effect:[\s\S]*?<\/details>/)[0];
  assert.match(eff, /a nested line/);
});

// ---- R4: states only

test("R4 noPartInStatesOnly: no part, no fold, no Guard text in the output", () => {
  const out = html(DESIGN, { statesOnly: true });
  assert.doesNotMatch(out, /<details/);
  assert.doesNotMatch(out.split("Coverage")[0], /guard text/);
  assert.match(out, /<p>Text of the state\.<\/p>/);
});

test("R4 Reading effect: two links per state, each with its part in the tip", () => {
  const out = html(DESIGN, { statesOnly: true });
  const links = out.match(/<span class="pp-link"[^>]*>(Effect|Invariants)<div class="pp-tip">[\s\S]*?<\/div><\/span>/g);
  assert.equal(links.length, 3);   // Ready: Effect, Invariants. Done: Invariants.
  assert.match(links[0], /^<span class="pp-link" tabindex="0">Effect<div class="pp-tip">.*the effect text\./s);
  assert.match(links[1], /Invariants.*inv_a/s);
  assert.doesNotMatch(out, /<ul[^>]*>\s*<\/ul>/);
  assert.match(out, /<div class="pp-links">/);   // a div: a <p> would close at the tip's <ul>
});

// ---- R2, R3: research answers

test("R7 marks: each research question's mark is its bullet, in place of the word, with its row marked on hover", () => {
  const out = html(INDEX, ctx());
  assert.equal(out.match(/class="pp-q"/g).length, 2);
  const items = out.match(/<li [^>]*data-pp-status[\s\S]*?<span class="pp-q"/g);
  assert.match(items[0], /list-style-type: '\u26AA '/);   // answered, not checked
  assert.match(items[0], /<span class="eb-row eb-on">\u26AA answered, not checked/);
  assert.match(items[1], /list-style-type: '\u{1F534} '/u);   // open, but the user disagrees: the feedback wins
  assert.match(items[1], /<span class="eb-first">You disagree: too broad<\/span>/);
  const dis = html(INDEX.replace("2. open", "2. answered"), ctx());
  assert.match(dis, /list-style-type: '\u{1F534} '/u);
  assert.doesNotMatch(out, />\s*(open|answered)\s*<span class="pp-q"/);   // the word is gone
});

test("R7 marks: an open question is a question mark, a deferred one the warning sign; an open question keeps its number", () => {
  const md = "## Open questions\n\n1. Now.\n2. \u26A0\uFE0F Later.\n3. [defer] Old way.\n\n## Research questions\n\n1. open Why?\n2. \u26A0\uFE0F open Later?\n";
  const out = html(md, { dir: "/kb", readFile: () => null, render: marked.parse });
  assert.match(out, /list-style-type: '2\. \u26A0\uFE0F '/);
  assert.match(out, /list-style-type: '3\. \u26A0\uFE0F '/);
  assert.match(out, /list-style-type: '\u2753 '[^>]*data-pp-status="open"/);
  assert.match(out, /data-pp-status="deferred"/);
  assert.doesNotMatch(out, /\[defer\]|\u26A0\uFE0F (open|Later)/);
});

test("R2: from a worktree, a link into another repo is read as from the main checkout", () => {
  const page = p => (p === "/sb/personal/a.staging.md" ? ANSWER : null);
  const out = html(INDEX.replace(/a\.staging\.md/g, "../../personal/a.staging.md"), ctx({ dir: "/sb/harness/.claude/worktrees/wt/plans", readFile: page }));
  assert.equal(out.match(/class="pp-q"/g).length, 2);
  assert.match(out, /<a href="\.\.\/\.\.\/\.\.\/\.\.\/\.\.\/personal\/a\.staging\.md#q1/);   // the link opens the file that was read
  assert.match(out, /data-pp-href="\.\.\/\.\.\/\.\.\/\.\.\/\.\.\/personal\/a\.staging\.md#q1"/);
});

test("R2: from a worktree, any other link into another repo goes to the main checkout's file", () => {
  const page = p => (p === "/sb/personal/b.md" ? "x" : null);
  const out = html("See [b](../../personal/b.md#top) and [web](https://e.com).\n", ctx({ dir: "/sb/harness/.claude/worktrees/wt/plans", readFile: page }));
  assert.match(out, /<a href="\.\.\/\.\.\/\.\.\/\.\.\/\.\.\/personal\/b\.md#top"/);
  assert.match(out, /<a href="https:\/\/e\.com"/);
  const tag = PP.apply('<a href="../../personal/b.md" data-href="../../personal/b.md">b</a>', ctx({ dir: "/sb/harness/.claude/worktrees/wt/plans", readFile: page }));
  assert.equal(tag.match(/="\.\.\/\.\.\/\.\.\/\.\.\/\.\.\/personal\/b\.md"/g).length, 2);   // href and data-href
});

test("R2 Popup effect: the whole answer page is embedded hidden, and the question heading is marked", () => {
  const out = html(INDEX, ctx());
  const full = out.match(/<div class="pp-full" hidden data-pp-id="2" data-pp-q="2" data-pp-href="[^"]*">[\s\S]*?<\/div>\s*<\/span>/)[0];
  assert.match(full, /Body of one\./);   // the whole page, not one section
  assert.match(full, /<h2 data-pp-q="2">Q2\. How does it open\?/);
  assert.match(full, /<h1>Answers<\/h1>/);
});

test("R3 Popup effect: a toggle of three vscode links, the current value marked", () => {
  const out = html(INDEX, ctx());
  const file = encodeURIComponent(encodeURIComponent("/kb/a.staging.md"));
  assert.ok(out.includes(`href="vscode://local.draw-graph-preview/feedback?file=${file}&amp;q=1&amp;value=agree"`) ||
            out.includes(`href="vscode://local.draw-graph-preview/feedback?file=${file}&q=1&value=agree"`));
  const toggles = out.match(/<div class="pp-fb"[\s\S]*?<\/div>/g);
  assert.equal((toggles[0].match(/class="pp-pick/g) || []).length, 3);
  assert.match(toggles[0], /pp-on" data-value="not_checked"/);
  assert.match(toggles[1], /pp-on" data-value="disagree"[^>]*title="too broad"/);
});

test("R2: a missing page or a missing question leaves the link as it was", () => {
  const a = html(INDEX, ctx({ readFile: () => null }));
  assert.doesNotMatch(a, /pp-q/);
  const b = html(INDEX.replace("#q2-", "#q9-"), ctx());
  assert.equal(b.match(/class="pp-q"/g).length, 1);
});

test("R2: questionSection stops at the next heading of its level", () => {
  const s = PP.questionSection(ANSWER, 1);
  assert.match(s, /Body of one/);
  assert.doesNotMatch(s, /Q2/);
  assert.equal(PP.questionSection(ANSWER, 7), null);
});

// ---- R3: the write

test("R3 Reason input effect: a disagree writes both lines of its question only", () => {
  const out = PP.setFeedback(ANSWER, 1, "disagree", "no\n\nsource  here");   // a line each, blank lines gone
  assert.match(out, /Q1[\s\S]*- \*\*User feedback:\*\* disagree\n- \*\*Disagree reason:\*\* no\n  - source here\n/);
  assert.match(out, /Q2[\s\S]*- \*\*User feedback:\*\* disagree\n- \*\*Disagree reason:\*\* too broad/);
});

test("R3 history: each change adds a dated line, and the same value adds none", () => {
  let t = PP.setFeedback(ANSWER, 1, "agree", "", "2026-10-24");
  t = PP.setFeedback(t, 1, "disagree", "too old", "2026-10-25");
  t = PP.setFeedback(t, 1, "disagree", "too old", "2026-10-26");
  t = PP.setFeedback(t, 1, "not_checked", "", "2026-10-27");
  const sec = PP.questionSection(t, 1);
  assert.match(sec, /- \*\*Feedback history:\*\*\n  - 2026-10-24: changed to agree\n  - 2026-10-25: changed to disagree, because too old\n  - 2026-10-27: changed to not_checked/);
  assert.doesNotMatch(sec, /2026-10-26/);
  assert.doesNotMatch(PP.questionSection(t, 2), /Feedback history/);   // only its own question
});

test("R3 reasonKept: agree and not_checked keep the last disagree reason, with the change at its end", () => {
  for (const v of ["agree", "not_checked"]) {
    const out = PP.setFeedback(ANSWER, 2, v, "", "2026-10-24");
    assert.match(out, new RegExp(`- \\*\\*User feedback:\\*\\* ${v}\\n- \\*\\*Disagree reason:\\*\\* too broad\\n  - ===\\n  - 2026-10-24: changed to ${v}\\n  - ===\\n- \\*\\*Feedback history:\\*\\*\\n  - 2026-10-24: changed to ${v}\\n\\n## Sources`));
  }
});

test("R3 disagreeHasReason: a disagree with no reason, or an unknown value, changes nothing", () => {
  assert.equal(PP.setFeedback(ANSWER, 1, "disagree", "  "), ANSWER);
  assert.equal(PP.setFeedback(ANSWER, 1, "maybe", ""), ANSWER);
  assert.equal(PP.setFeedback(ANSWER, 9, "agree", ""), ANSWER);
});

test("R3: a question with no feedback lines gets them after its last field", () => {
  const out = PP.setFeedback("## Q1. A\n\n- **Status:** yes\n- **Sources:** [1]\n\nBody\n", 1, "agree", "", "2026-10-24");
  assert.equal(out, "## Q1. A\n\n- **Status:** yes\n- **Sources:** [1]\n- **User feedback:** agree\n- **Disagree reason:**\n- **Feedback history:**\n  - 2026-10-24: changed to agree\n\nBody\n");
});

test("R3 fileMatchesPreview: the link of each value, applied, gives the value the mark then shows", () => {
  for (const v of ["agree", "disagree", "not_checked"]) {
    const reason = v === "disagree" ? "no source" : "";
    const uri = PP.feedbackUri("/kb/a.staging.md", 1, v, reason);
    const p = PP.parseFeedbackUri(decodeURIComponent(uri.split("?")[1]));   // VS Code decodes the query once
    assert.deepEqual(p, { file: "/kb/a.staging.md", q: 1, value: v, reason });
    const written = PP.setFeedback(ANSWER, p.q, p.value, p.reason);
    const shown = html(INDEX, ctx({ readFile: () => written }));
    assert.match(shown, new RegExp(`list-style-type: '${{ agree: "\u{1F7E2}", disagree: "\u{1F534}", not_checked: "\u26AA" }[v]} '`, "u"));
  }
});

test("R3: the uri carries a reason with spaces and symbols whole", () => {
  const reason = "a & b + c = 100%\n===\nnext";
  const uri = PP.feedbackUri("/kb/a b.md", 3, "disagree", reason);
  // as the handler gets it: VS Code decodes uri.query once
  assert.deepEqual(PP.parseFeedbackUri(decodeURIComponent(uri.split("?")[1])), { file: "/kb/a b.md", q: 3, value: "disagree", reason });
  assert.equal(PP.parseFeedbackUri("file=x&q=1&value=bad"), null);
});

// ---- R5, R6

test("R5: no emoji but the four marks, none in the stylesheet, and only palette colours", () => {
  const out = html(INDEX + DESIGN, ctx()) + html(DESIGN, { statesOnly: true });
  assert.doesNotMatch(out.replace(/<span class="eb-legend"[\s\S]*?<\/span><\/span>/g, "").replace(/list-style-type: '[^']*'/g, ""), /\p{Extended_Pictographic}/u);
  const css = fs.readFileSync(path.join(__dirname, "../plan-preview.css"), "utf8");
  assert.doesNotMatch(css, /\p{Extended_Pictographic}/u);
  assert.doesNotMatch(css, /#[0-9a-fA-F]{3,6}\b/);
  assert.match(css, /var\(--pal-/);
});

test("R6: the library loads in node, and the page side does nothing without a document", () => {
  assert.equal(typeof PP.apply, "function");
  assert.doesNotThrow(() => PP.preview());
});

test("R3 reasonKept: each move adds its line between === lines, and the next disagree reads them all back", () => {
  let t = PP.setFeedback(ANSWER, 1, "disagree", "sadf", "2026-10-24 22:00");
  t = PP.setFeedback(t, 1, "agree", "", "2026-10-24 22:01");
  t = PP.setFeedback(t, 1, "not_checked", "", "2026-10-24 22:02");
  const sec = PP.questionSection(t, 1);
  assert.match(sec, /- \*\*Disagree reason:\*\* sadf\n  - ===\n  - 2026-10-24 22:01: changed to agree\n  - ===\n  - 2026-10-24 22:02: changed to not_checked\n  - ===\n- \*\*Feedback history:\*\*/);
  // The user edits the note in the text box and sends it: the new lines replace the old ones
  t = PP.setFeedback(t, 1, "disagree", "sadf\n===\nstill no source", "2026-10-24 22:03");
  assert.match(PP.questionSection(t, 1), /- \*\*Disagree reason:\*\* sadf\n  - ===\n  - still no source\n- \*\*Feedback history:\*\*/);
  assert.match(PP.questionSection(t, 1), /2026-10-24 22:03: changed to disagree, because sadf$/m);
});

test("R2: a link inside the answer page goes where it went from the answer page's own folder", () => {
  const page = ANSWER.replace("Body of one.", "See [the other](other.md).");
  const out = html(INDEX.replace(/a\.staging\.md/g, "kb/a.staging.md"), ctx({ dir: "/plans", readFile: p => (p === "/plans/kb/a.staging.md" ? page : null) }));
  assert.ok(out.includes('href="kb/other.md"'));
  assert.ok(!out.includes('href="other.md"'));
});
