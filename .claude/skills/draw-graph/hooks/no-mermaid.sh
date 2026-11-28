#!/usr/bin/env bash
# PreToolUse hook on Write, Edit and MultiEdit. Blocks a write that puts a
# ```mermaid block in a markdown file: graphs are ```graph blocks (draw-graph R13).
# Exit 2 blocks the tool call and shows stderr to Claude. Anything else lets it run.
in="$(cat)"
f="$(jq -r '.tool_input.file_path // empty' <<<"$in")"
[[ "$f" == *.md ]] || exit 0
jq -r '.tool_input | .content, .new_string, (.edits // [] | .[].new_string) | strings' <<<"$in" \
  | grep -qE '^[[:space:]]*(```|~~~)[[:space:]]*mermaid' || exit 0

cat >&2 <<MSG
$f: do not write a Mermaid block. Draw the graph as a \`\`\`graph block, in the
format the draw-graph skill gives (load it with the Skill tool). Convert the
Mermaid you meant to write: nodes, groups, links and link text map one to one.
MSG
exit 2
