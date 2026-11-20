#!/bin/bash
# The folder part of the status line: each folder the session added, grouped under its
# project from the project map. Reads the status line JSON on stdin, prints one line or
# nothing. ~/.claude/statusline.sh calls it.
# Plan: plans/global/components/multi-folder/components/folder-status/.
map="$(dirname "${BASH_SOURCE[0]}")/project-map.py"
input=$(cat)
dirs=$(jq -r '.workspace.added_dirs // [] | .[]' <<< "$input" 2>/dev/null) || exit 0
# Save the added folders for the other multi-folder parts, which cannot see them.
sid=$(jq -r '.session_id // empty' <<< "$input" 2>/dev/null)
if [ -n "$sid" ]; then
  st="${CLAUDE_MULTI_FOLDER_STATE:-$HOME/.claude/multi-folder}/${sid//[^A-Za-z0-9_-]/_}"
  mkdir -p "$st" 2>/dev/null && printf '%s' "${dirs:+$dirs$'\n'}" > "$st/dirs.tmp" && mv "$st/dirs.tmp" "$st/dirs"
fi
[ -z "$dirs" ] && exit 0
while IFS= read -r d; do
  # A folder on no row gets its own name back. If that name is also a project on the map,
  # the folder has a row: ponytail: a folder on no row named as another project groups
  # under it, rare, fix with a no-row exit of project-map.py if it shows up.
  p=$(python3 -I "$map" project "$d" 2>/dev/null)
  row=1
  [ "$p" = "$(basename "${d%/}")" ] && ! python3 -I "$map" folders "$p" >/dev/null 2>&1 && row=0
  printf '%s\t%s\t%s\n' "$row" "$p" "$d"
done <<< "$dirs" | python3 -I -c '
import os, sys
groups = {}
for line in sys.stdin:
    row, project, d = line.rstrip("\n").split("\t", 2)
    name = os.path.basename(d.rstrip("/")) or d
    key = ("project", project) if row == "1" and project else ("dir", d)
    groups.setdefault(key, []).append(name)
parts = [", ".join(n) if k[0] == "dir" or n == [k[1]] else k[1] + "(" + ",".join(n) + ")" for k, n in groups.items()]
print("+ " + "  ".join(parts))
'
