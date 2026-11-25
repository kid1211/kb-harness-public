#!/bin/bash
# statusline-folders.sh: the domain line of the status line and the domain file of the session, one case per
# state of plans/global/components/multi-folder/components/folder-status/folder-status.qnt.
script="$(cd "$(dirname "$0")/../../.." && pwd)/scripts/statusline-folders.sh"
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
g() { git -C "$1" -c user.name=t -c user.email=t@t "${@:2}"; }
mkdir -p "$t/code/web/src" "$t/code/api" "$t/notes" "$t/kb" "$t/h" "$t/odd"
for d in code/web code/api kb h odd; do g "$t/$d" init -q; echo x > "$t/$d/f"; g "$t/$d" add f; g "$t/$d" commit -qm x; done
g "$t/code/web" worktree add -q "$t/code/web/.claude/worktrees/w" -b w
cat > "$t/map.md" <<EOF
| Project | Folder | Role |
|---|---|---|
| shop | $t/code/web | frontend |
| shop | $t/code/api | backend |
| shop | $t/kb | KB |
| shop | $t/notes | frontend |
| shop | $t/odd | weird |
| harness | $t/h | tooling |
| web | $t/code/web | frontend |
EOF
run() { echo "$1" | PROJECT_MAP="$t/map.md" bash "$script"; }
j() { local a=; for d in "$@"; do a+="${a:+,}\"$d\""; done; echo "{\"workspace\":{\"added_dirs\":[$a]}}"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$(cat -v <<< "$out")] (exit $rc)"; fail=1; fi; }
plain() { sed $'s/\033\\[[0-9;]*m//g' <<< "$out"; }
l1() { plain | sed -n 1p; }
l2() { plain | sed -n 2p; }

# quiet: quietWhenNone, noneTest
out=$(run '{"workspace":{"current_dir":"/x"}}'); rc=$?
ok "no added_dirs prints only no domain" '[ $rc = 0 ] && [ "$out" = "no domain" ]'
out=$(run "$(j)"); rc=$?
ok "an empty added_dirs prints only no domain" '[ $rc = 0 ] && [ "$out" = "no domain" ]'
# shown: domainShown
out=$(run "$(j "$t/code/web" "$t/code/api" "$t/kb" "$t/notes" "$t/odd" "$t/h")"); rc=$?
ok "the status line is one line: the domains" '[ "$out" = "shop, harness" ]'
out=$(run "$(j "$t/kb" "$t/notes")"); rc=$?
ok "no full domain prints no domain" '[ "$out" = "no domain" ]'
out=$(run 'not json'); rc=$?
ok "bad input prints nothing and exits 0" '[ $rc = 0 ] && [ -z "$out" ]'
# recordedAll: the session file holds the added folders
st="$t/state"
out=$(echo "{\"session_id\":\"s1\",\"workspace\":{\"added_dirs\":[\"$t/code/web\",\"$t/notes\"]}}" | CLAUDE_MULTI_FOLDER_STATE="$st" PROJECT_MAP="$t/map.md" bash "$script"); rc=$?
ok "the session file holds the added folders" '[ "$(cat "$st/s1/dirs" 2>/dev/null)" = "$t/code/web
$t/notes" ]'
out=$(echo '{"session_id":"s1","workspace":{"added_dirs":[]}}' | CLAUDE_MULTI_FOLDER_STATE="$st" bash "$script"); rc=$?
ok "with no added folder the session files are empty" '[ -f "$st/s1/dirs" ] && [ ! -s "$st/s1/dirs" ] && [ -f "$st/s1/domain" ] && [ ! -s "$st/s1/domain" ] && [ "$out" = "no domain" ]'
# domainShown, domainsOf: the domain file names the largest full domains
dom() { echo "{\"session_id\":\"s2\",\"workspace\":{\"added_dirs\":[$1]}}" | CLAUDE_MULTI_FOLDER_STATE="$st" PROJECT_MAP="$t/map.md" bash "$script" >/dev/null; cat "$st/s2/domain"; }
all="\"$t/code/web\",\"$t/code/api\",\"$t/kb\",\"$t/notes\",\"$t/odd\",\"$t/h\""
out=$(dom "$all")
ok "every folder added: the domain file names shop and harness, not web inside shop" '[ "$out" = "shop, harness" ]'
out=$(dom "\"$t/code/web\"")
ok "web alone: the domain file names web" '[ "$out" = "web" ]'
out=$(dom "\"$t/code/api\"")
ok "a domain not all added: the domain file is empty" '[ -z "$out" ]'
# group: project-map.py role, the longest row
printf '| Project | Folder | Role |\n|---|---|---|\n| p | %s/code | outer |\n| p | %s/code/api | inner |\n' "$t" "$t" > "$t/m2.md"
out=$(PROJECT_MAP="$t/m2.md" python3 -I "$(dirname "$script")/project-map.py" role "$t/code/api/x"); rc=$?
ok "project-map.py role gives the Role cell of the longest row" '[ "$out" = inner ]'
exit $fail
