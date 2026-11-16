#!/usr/bin/env bash
# PostToolUse hook on Write, Edit and MultiEdit. When a markdown file holds a ```graph
# block, draw each graph and report the layout rules it breaks (graph-check R1).
# Exit 2 shows the report to Claude, to fix the graph text. Anything else is silent.
f="$(jq -r '.tool_input.file_path // empty')"
[[ "$f" == *.md && -f "$f" ]] && grep -qE '^[[:space:]]*```graph[[:space:]]*$' "$f" || exit 0
here="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
out="$(node "$here/../../../lib/draw-graph/check.js" "$f" 2>&1)"
case $? in
  0) [[ -n "$out" ]] && echo "$out" >&2; exit 0 ;;   # passed, or did not run (says why)
  1) printf '%s\n%s\n' "$out" "Fix the graph text (draw-graph skill): reorder links, shorten text, split the graph, or drop a group." >&2; exit 2 ;;
  *) echo "graph check did not run: $out" >&2; exit 0 ;;
esac
