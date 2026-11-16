#!/usr/bin/env bash
# Checks hooks/no-mermaid.sh: it blocks a Mermaid block in a markdown file, and nothing else.
set -uo pipefail
hook="$(cd "$(dirname "$0")/.." && pwd)/hooks/no-mermaid.sh"
fail=0
t() { printf '%s' "$2" | "$hook" >/dev/null 2>&1; local got=$?
  [[ $got == "$1" ]] || { echo "FAIL $3: exit $got, want $1"; fail=1; }; }

t 2 '{"tool_input":{"file_path":"/x/a.md","content":"x\n```mermaid\nflowchart LR\n```"}}' "Write with a Mermaid block"
t 2 '{"tool_input":{"file_path":"/x/a.md","new_string":"  ```mermaid"}}' "Edit with an indented block"
t 2 '{"tool_input":{"file_path":"/x/a.md","edits":[{"new_string":"ok"},{"new_string":"~~~mermaid"}]}}' "MultiEdit with a ~~~ block"
t 0 '{"tool_input":{"file_path":"/x/a.md","content":"```graph\na -> b\n```"}}' "a graph block"
t 0 '{"tool_input":{"file_path":"/x/a.md","content":"the word ```` ```mermaid ```` inline"}}' "Mermaid named inline"
t 0 '{"tool_input":{"file_path":"/x/a.js","content":"```mermaid"}}' "a file that is not markdown"

[[ $fail == 0 ]] && echo "ok   no-mermaid hook"
exit $fail
