#!/usr/bin/env bash
# PostToolUse(Bash) hook: after a `git commit`, check that the folder of the
# commit is on the project map (scripts/project-map.py check). If the map is
# missing, tell Claude to set it up. If the folder is on no row, tell Claude to
# ask the user to add it. Never blocks: any failure exits 0 with no output.
# Plan: plans/global/components/multi-folder/components/project-map/ (F5).

set -uo pipefail

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)" || exit 0
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)" || exit 0
re='(^|[;&|(]|[[:space:]])git(([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*)[[:space:]]+commit([[:space:]]|$)'
[[ $cmd =~ $re ]] || exit 0

# The folder of the commit: the last `-C <dir>` of the git call, else the cwd.
dir="${cwd:-$PWD}"
opts="${BASH_REMATCH[2]}"
while [[ $opts =~ -C[[:space:]]+([^[:space:]]+)(.*) ]]; do
  d="${BASH_REMATCH[1]}"; opts="${BASH_REMATCH[2]}"
  d="${d%\"}"; d="${d#\"}"; d="${d/#\~/$HOME}"
  [[ $d == /* ]] && dir="$d" || dir="$dir/$d"
done
top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || exit 0

here="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
out="$(python3 -I "$here/scripts/project-map.py" check "$top" 2>&1)"
rc=$?
# A KB repo split into domains has rows inside it, and none of its own: that passes too.
[ $rc = 1 ] && python3 -I "$here/scripts/project-map.py" list 2>/dev/null | tr ' ' '\n' | grep -q "^$top/" && exit 0
case $rc in
  0) exit 0 ;;
  1) msg="A git commit just ran in $top, and that folder is not on the project map. Ask the user for its project, its role (such as frontend, backend or KB) and its KB, then add one row for it to the map ($out)." ;;
  2) msg="A git commit just ran in $top, but there is no project map ($out). Set it up: copy projects-mapping.md.template in the harness main checkout to projects-mapping.md there (git ignores it). Then ask the user for the project, role and KB of each folder they work in, this one first, and add a row for each." ;;
  *) exit 0 ;;
esac
jq -n --arg c "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
exit 0
