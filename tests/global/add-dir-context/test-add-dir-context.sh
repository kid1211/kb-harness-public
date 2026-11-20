#!/bin/bash
# add-dir-context.sh and folder-context.py: one case per run and invariant of
# plans/global/components/multi-folder/components/add-dir-context/add-dir-context.qnt.
root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
hook="$root/.claude/hooks/add-dir-context.sh"
ctx="$root/scripts/folder-context.py"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/code/shop-web" "$t/code/shop-api" "$t/kb/shop" "$t/notes"
cat > "$t/map.md" <<EOF
| Project | Folder | Role | KB | Note |
|---|---|---|---|---|
| shop | $t/code/shop-web | code | shopkb | the frontend |
| shop | $t/code/shop-api | code | shopkb | the backend |
| shopkb | $t/kb/shop | KB | shopkb | the docs |
EOF
export PROJECT_MAP="$t/map.md" CLAUDE_MULTI_FOLDER_STATE="$t/state"
added() { printf '{"session_id":"%s","hook_event_name":"DirectoryAdded","directory":"%s","source":"slash_command"}' "$1" "$2" | bash "$hook"; }
prompt() { printf '{"session_id":"%s","hook_event_name":"UserPromptSubmit","prompt":"hi"}' "$1" | bash "$hook"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out] (exit $rc)"; fail=1; fi; }

# recorded: record, recordQuiet, addTest
out=$(added s1 "$t/code/shop-web"); rc=$?
ok "an add saves the folder and prints nothing" '[ $rc = 0 ] && [ -z "$out" ] && grep -Fxq "$t/code/shop-web" "$t/state/s1/dirs"'
out=$(added s1 "$t/code/shop-web"); rc=$?
ok "a second add of one folder saves it once" '[ "$(grep -c . "$t/state/s1/dirs")" = 1 ]'
# told: tell, toldFromDirs, tellTest
echo "$t/notes" >> "$t/state/s1/dirs"
out=$(prompt s1); rc=$?
ok "a prompt gives the project and role" '[ $rc = 0 ] && [[ $out == *"Folder $t/code/shop-web: project shop, role code."* ]]'
ok "a prompt gives the supporting docs with their role" '[[ $out == *"Supporting docs of shop: $t/kb/shop (KB)"* ]]'
ok "a folder on no row gets the no-row line" '[[ $out == *"Folder $t/notes: on no row of the project map."* ]]'
ok "the output is UserPromptSubmit JSON" 'python3 -I -c "import json,sys; h=json.loads(sys.argv[1])[\"hookSpecificOutput\"]; assert h[\"hookEventName\"]==\"UserPromptSubmit\" and h[\"additionalContext\"].startswith(\"Folders added to this session\")" "$out"'
# silent: quiet, toldSaved, onceTest
out=$(prompt s1); rc=$?
ok "a second prompt gives nothing" '[ $rc = 0 ] && [ -z "$out" ]'
ok "the told file holds only saved folders" '[ -s "$t/state/s1/told" ] && ! grep -Fxvf "$t/state/s1/dirs" "$t/state/s1/told" | grep -q .'
# --json for the folder pane
out=$(python3 -I "$ctx" --json "$t/code/shop-api" "$t/notes"); rc=$?
ok "--json gives project, role and docs" 'python3 -I -c "import json,sys; a=json.loads(sys.argv[1]); assert a[0][\"project\"]==\"shop\" and a[0][\"role\"]==\"code\" and a[0][\"docs\"]==[{\"folder\":sys.argv[2],\"role\":\"KB\",\"project\":\"shopkb\"}] and a[1][\"project\"] is None" "$out" "$t/kb/shop"'
# F4: never blocks
out=$(echo 'not json' | bash "$hook"); rc=$?
ok "bad input exits 0 with no output" '[ $rc = 0 ] && [ -z "$out" ]'
# wiring
for ev in DirectoryAdded UserPromptSubmit; do
  ok "settings run the hook on $ev" 'python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); assert any(\"add-dir-context.sh\" in h[\"command\"] for e in d[\"hooks\"][sys.argv[2]] for h in e[\"hooks\"])" "$root/.claude/settings.json" '$ev''
done
exit $fail
