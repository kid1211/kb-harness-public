#!/bin/bash
# project-map F6: a KB repo split into domains. project-map.py domains gives each domain with
# its folders and roles as JSON, for the domains pane, and the commit check passes a repo that
# holds a row and has none of its own.
root="$(cd "$(dirname "$0")/../../.." && pwd)"
map="$root/scripts/project-map.py"
hook="$root/.claude/hooks/project-map-check.sh"
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/p/trade" "$t/p/me" "$t/p/other" "$t/web" "$t/lone"
git -C "$t/p" init -q; git -C "$t/lone" init -q
cat > "$t/map.md" <<EOF
| Project | Folder | Role | KB | Note |
|---|---|---|---|---|
| trade | $t/p/trade | KB | personal | the trade domain |
| health | $t/p/me | KB | personal | my health |
| shop | $t/web | frontend | personal | the shop site |
| health | $t/p/other | KB | personal | other health |
| shop | $t/p/me | KB | personal | a folder in two domains |
EOF
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out]"; fail=1; fi; }

out=$(PROJECT_MAP="$t/map.md" python3 -I "$map" domains); rc=$?
want=$(printf '[{"name": "trade", "folders": [{"folder": "%s/p/trade", "role": "KB"}]}, {"name": "health", "folders": [{"folder": "%s/p/me", "role": "KB"}, {"folder": "%s/p/other", "role": "KB"}]}, {"name": "shop", "folders": [{"folder": "%s/web", "role": "frontend"}, {"folder": "%s/p/me", "role": "KB"}]}]' "$t" "$t" "$t" "$t" "$t")
ok "domains gives each domain once, in map order, with its folders and roles" '[ $rc = 0 ] && [ "$out" = "$want" ]'
ok "a folder in two domains has its own role in each" '[[ $out == *"\"shop\", \"folders\": [{\"folder\": \"$t/web\""* ]]'
out=$(PROJECT_MAP="$t/none.md" python3 -I "$map" domains 2>&1); rc=$?
ok "domains with no map exits 2" '[ $rc = 2 ]'

call() { jq -n --arg c "git commit -m x" --arg d "$1" '{tool_input: {command: $c}, cwd: $d}' | PROJECT_MAP="$t/map.md" bash "$hook"; }
out=$(call "$t/p")
ok "a commit in a repo that holds a row prints nothing" '[ -z "$out" ]'
out=$(call "$t/lone")
ok "a commit in a repo with no row in it still asks" '[[ $out == *"Ask the user"* ]]'
exit $fail
