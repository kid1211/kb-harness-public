#!/bin/bash
# statusline-folders.sh: the folder part of the status line, one case per state of
# plans/global/components/multi-folder/components/folder-status/folder-status.qnt.
script="$(cd "$(dirname "$0")/../../.." && pwd)/scripts/statusline-folders.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/code/shop-web" "$t/code/shop-api" "$t/notes"
cat > "$t/map.md" <<EOF
| Project | Folder |
|---|---|
| shop | $t/code/shop-web |
| shop | $t/code/shop-api |
EOF
run() { echo "$1" | PROJECT_MAP="$t/map.md" bash "$script"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out] (exit $rc)"; fail=1; fi; }

# quiet: quietWhenNone, noneTest
out=$(run '{"workspace":{"current_dir":"/x"}}'); rc=$?
ok "no added_dirs prints nothing" '[ $rc = 0 ] && [ -z "$out" ]'
out=$(run '{"workspace":{"current_dir":"/x","added_dirs":[]}}'); rc=$?
ok "an empty added_dirs prints nothing" '[ $rc = 0 ] && [ -z "$out" ]'
# shown: projectOnce, eachFolderShown, twoFoldersTest
out=$(run "{\"workspace\":{\"added_dirs\":[\"$t/code/shop-web\",\"$t/code/shop-api\",\"$t/notes\"]}}"); rc=$?
ok "two folders of one project show the project once, then the other folder" '[ "$out" = "+ shop(shop-web,shop-api)  notes" ]'
out=$(run "{\"workspace\":{\"added_dirs\":[\"$t/notes\"]}}"); rc=$?
ok "a folder on no row shows its own name" '[ "$out" = "+ notes" ]'
out=$(run 'not json'); rc=$?
ok "bad input prints nothing and exits 0" '[ $rc = 0 ] && [ -z "$out" ]'
# shown: projectOnce, when a folder has the name of its project
mkdir -p "$t/two/shop" "$t/two/shop-api"
printf '| Project | Folder |\n|---|---|\n| shop | %s |\n| shop | %s |\n' "$t/two/shop" "$t/two/shop-api" > "$t/same.md"
out=$(echo "{\"workspace\":{\"added_dirs\":[\"$t/two/shop\",\"$t/two/shop-api\"]}}" | PROJECT_MAP="$t/same.md" bash "$script"); rc=$?
ok "a folder named as its project still groups under it" '[ "$out" = "+ shop(shop,shop-api)" ]'
out=$(echo "{\"workspace\":{\"added_dirs\":[\"$t/two/shop\"]}}" | PROJECT_MAP="$t/same.md" bash "$script"); rc=$?
ok "one folder named as its project shows the name once" '[ "$out" = "+ shop" ]'
# recordedAll: the session file holds the added folders
st="$t/state"
out=$(echo "{\"session_id\":\"s1\",\"workspace\":{\"added_dirs\":[\"$t/code/shop-web\",\"$t/notes\"]}}" | CLAUDE_MULTI_FOLDER_STATE="$st" PROJECT_MAP="$t/map.md" bash "$script"); rc=$?
ok "the session file holds the added folders" '[ "$(cat "$st/s1/dirs" 2>/dev/null)" = "$t/code/shop-web
$t/notes" ]'
out=$(echo '{"session_id":"s1","workspace":{"added_dirs":[]}}' | CLAUDE_MULTI_FOLDER_STATE="$st" bash "$script"); rc=$?
ok "with no added folder the session file is empty" '[ -f "$st/s1/dirs" ] && [ ! -s "$st/s1/dirs" ] && [ -z "$out" ]'
# the inline python must parse on a python3 before 3.12
ok "no double quotes inside a double-quoted f-string" '! grep -qE "f\"[^\"]*\{[^}]*\"" "$script"'
exit $fail
