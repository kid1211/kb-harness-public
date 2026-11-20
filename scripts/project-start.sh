#!/bin/bash
# Start claude in the harness with each folder of one project added by --add-dir, so the
# harness hooks run and each folder's own skills load.
#
#   project-start.sh <project> [claude args...]
#
# The folders come from the project map (scripts/project-map.py).
# Plan: plans/global/components/multi-folder/components/project-start/.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
map="$root/scripts/project-map.py"
if [ $# -lt 1 ]; then
  echo "usage: project-start.sh <project> [claude args...]" >&2
  python3 -I "$map" list >&2
  exit 64
fi
project=$1; shift
folders=$(python3 -I "$map" folders "$project") || { rc=$?; [ -n "$folders" ] && printf '%s\n' "$folders" >&2; exit $rc; }

args=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ ! -d "$f" ]; then echo "missing: $f" >&2; continue; fi
  [ "$(cd "$f" && pwd -P)" = "$root" ] && continue
  args+=(--add-dir "$f")
done <<< "$folders"
cd "$root" && exec claude "${args[@]}" "$@"
