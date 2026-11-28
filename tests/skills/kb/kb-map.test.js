// Run: node --test tests/skills/kb/kb-map.test.js
// The map page logic, against a small tree like the one kb-types.py map writes.
const test = require("node:test");
const assert = require("node:assert/strict");
const { start, click, reset } = require("../../../.claude/skills/kb/assets/kb-map.js");

// Levels: 0 all KBs, 1 KB, 2 domain, 3 area, 4 type or page, 5 field.
const TREE = {
  nodes: {
    "all": { name: "all KBs", parent: null, level: 0 },
    "personal": { name: "personal", parent: "all", level: 1 },
    "eventPNL": { name: "eventPNL", parent: "all", level: 1 },
    "personal/food": { name: "food", parent: "personal", level: 2 },
    "personal/food/consolidated": { name: "consolidated (1)", parent: "personal/food", level: 3 },
    "personal/food/item": { name: "item", parent: "personal/food/consolidated", level: 4 },
    "personal/food/item#fresh_days": { name: "fresh_days", parent: "personal/food/item", level: 5 },
    "personal/food/miscellaneous": { name: "miscellaneous (1)", parent: "personal/food/consolidated", level: 4, folded: true },
    "personal/food/miscellaneous#notes.md": { name: "notes.md", parent: "personal/food/miscellaneous", level: 5 },
  },
  home: "personal/food",
};

test("fullTest: the page shows its whole folder, every level down, and nothing outside it", () => {
  const st = start(TREE);
  assert.ok(st.visible.has("personal/food"));
  assert.ok(st.visible.has("personal/food/item#fresh_days"), "a field three levels down shows");
  assert.ok(!st.visible.has("personal") && !st.visible.has("eventPNL") && !st.visible.has("all"), "no level over the page's folder");
});

test("foldTest: a folded node shows with its count, and a click opens and closes it", () => {
  const st = start(TREE);
  assert.ok(st.visible.has("personal/food/miscellaneous"));
  assert.ok(!st.visible.has("personal/food/miscellaneous#notes.md"), "its pages are folded away");
  const open = click(TREE, st, "personal/food/miscellaneous");
  assert.ok(open.visible.has("personal/food/miscellaneous#notes.md"), "a click opens it");
  assert.ok(!click(TREE, open, "personal/food/miscellaneous").visible.has("personal/food/miscellaneous#notes.md"), "a second click closes it");
});

test("clickTest: a click on a node that does not fold changes nothing", () => {
  const st = start(TREE);
  assert.deepEqual([...click(TREE, st, "personal/food/item").visible].sort(), [...st.visible].sort());
});

test("resetTest: Reset folds each node again", () => {
  const open = click(TREE, start(TREE), "personal/food/miscellaneous");
  assert.deepEqual([...reset(TREE).visible].sort(), [...start(TREE).visible].sort());
  assert.ok(!reset(TREE).visible.has("personal/food/miscellaneous#notes.md") && open.visible.size > reset(TREE).visible.size);
});
