#!/bin/bash
# project-map-check.sh: the hook after a git commit, on a throwaway map.
# F5 of plans/global/components/multi-folder/components/project-map/.
root="$(cd "$(dirname "$0")/../../.." && pwd)"
hook="$root/.claude/hooks/project-map-check.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/mapped/sub" "$t/other"
git -C "$t/mapped" init -q; git -C "$t/other" init -q
printf '| Project | Folder |\n|---|---|\n| shop | %s |\n' "$t/mapped" > "$t/map.md"
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: $out"; fail=1; fi; }
call() { jq -n --arg c "$1" --arg d "$2" '{tool_input: {command: $c}, cwd: $d}' | PROJECT_MAP="${3:-$t/map.md}" bash "$hook"; }

out=$(call "git commit -m x" "$t/mapped/sub")
ok "a commit in a mapped folder prints nothing" '[ -z "$out" ]'
out=$(call "git -C $t/other commit -m x" "$t/mapped")
ok "git -C to a folder on no row names that folder" '[[ $out == *additionalContext* ]] && [[ $out == *"$t/other"* ]] && [[ $out == *"Ask the user"* ]]'
out=$(call "git commit -m x" "$t/other")
ok "a commit in the cwd on no row names the cwd repo" '[[ $out == *"$t/other"* ]]'
out=$(call "git commit -m x" "$t/mapped" "$t/none.md")
ok "no map tells Claude to set it up from the template" '[[ $out == *projects-mapping.md.template* ]]'
out=$(call "git status" "$t/other")
ok "a call with no commit prints nothing" '[ -z "$out" ]'
out=$(call "git commit -m x" "$t")
ok "a commit outside a repo prints nothing" '[ -z "$out" ]'
exit $fail
