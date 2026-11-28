// import-graph.js - a ```graph block that holds one line, `import-graph: <path>`, draws
// the graph of another .md file (plans/draw-graph R18). The file must be one graph block
// and nothing else: the first line ```graph, the last line ```, no other fence. A blank
// file is an empty graph. A file that itself imports is refused.
// Used in node by the VS Code preview's markdown-it plugin and by check.js.
const fs = require("node:fs");
const path = require("node:path");

// The path of an import block, or null if the block is a normal graph.
function importPath(text) {
  const m = /^\s*import-graph:\s*(\S+)\s*$/.exec(text);
  return m ? m[1] : null;
}

// The graph text of a file's whole content, or an Error that says why it is not one block.
function graphOf(content) {
  if (!/\S/.test(content)) return "";
  const lines = content.replace(/\s+$/, "").split("\n");
  if (lines[0] !== "```graph") return new Error("its first line is not ```graph");
  const fences = lines.slice(1).map((l, i) => /^```/.test(l) ? i + 1 : -1).filter(i => i > 0);
  if (fences.length !== 1 || fences[0] !== lines.length - 1) return new Error("it is not one graph block and nothing else");
  const body = lines.slice(1, -1).join("\n");
  if (importPath(body) !== null) return new Error("it is itself an import");
  return body;
}

// Resolve an import block of the page at `from`: the graph text, or an Error.
function resolve(text, from) {
  const rel = importPath(text);
  if (rel === null) return text;
  const file = path.resolve(path.dirname(from), rel);
  let content;
  try { content = fs.readFileSync(file, "utf8"); }
  catch { return new Error(`import-graph: ${rel}: no such file`); }
  const g = graphOf(content);
  return g instanceof Error ? new Error(`import-graph: ${rel}: ${g.message}`) : g;
}

module.exports = { importPath, graphOf, resolve };
