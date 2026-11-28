// import-graph: the import line, the one-block rule, and the errors.
const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { importPath, graphOf, resolve } = require("../import-graph.js");

test("importPath reads only an import line", () => {
  assert.equal(importPath("import-graph: architecture.md"), "architecture.md");
  assert.equal(importPath("\nimport-graph: a/b.md\n"), "a/b.md");
  assert.equal(importPath("a -> b"), null);
  assert.equal(importPath("import-graph: a.md\na -> b"), null);
});

test("graphOf takes one graph block and nothing else", () => {
  assert.equal(graphOf("```graph\na -> b\n```\n"), "a -> b");
  assert.equal(graphOf(""), "");
  assert.ok(graphOf("# Title\n```graph\na -> b\n```\n") instanceof Error);
  assert.ok(graphOf("```graph\na -> b\n```\nmore\n") instanceof Error);
  assert.ok(graphOf("```graph\na\n```\n```graph\nb\n```\n") instanceof Error);
  assert.ok(graphOf("```graph\nimport-graph: c.md\n```\n") instanceof Error);
});

test("resolve reads the file next to the page", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ig-"));
  fs.writeFileSync(path.join(dir, "architecture.md"), "```graph\nx -> y\n```\n");
  const page = path.join(dir, "0-index.md");
  assert.equal(resolve("import-graph: architecture.md", page), "x -> y");
  assert.equal(resolve("a -> b", page), "a -> b");
  assert.match(resolve("import-graph: none.md", page).message, /no such file/);
});
