#!/bin/bash
# project-map.py: look-ups on a throwaway map page, one case per state of
# plans/global/components/multi-folder/components/project-map/project-map.qnt.
script="$(cd "$(dirname "$0")/../../.." && pwd)/scripts/project-map.py"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/code/shop-web/src" "$t/code/shop-api" "$t/code/shop-web/admin"
cat > "$t/map.md" <<EOF
# Projects

Some text.

| Project | Folder | Role | KB |
|---|---|---|---|
| shop | $t/code/shop-web | frontend | personal |
| shop | $t/code/shop-api | backend | personal |
| admin | $t/code/shop-web/admin | admin page | |
| home | ~/zz-not-here | the home folder | |
EOF
run() { PROJECT_MAP="$t/map.md" python3 -I "$script" "$@"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: $out (exit $rc)"; fail=1; fi; }

# folders: foldersMatch, foldersTest
out=$(run folders shop); rc=$?
ok "folders prints both folders, in page order" '[ $rc = 0 ] && [ "$out" = "$t/code/shop-web
$t/code/shop-api" ]'
# project: projectMatch, projectTest
out=$(run project "$t/code/shop-web/src/a.ts"); rc=$?
ok "project of a file deep in a folder" '[ $rc = 0 ] && [ "$out" = shop ]'
out=$(run project "$t/code/shop-web/admin/x.ts"); rc=$?
ok "a nested folder wins over its parent" '[ "$out" = admin ]'
out=$(run project "$t/code/shop-api"); rc=$?
ok "project of the folder itself" '[ "$out" = shop ]'
out=$(run project "$t/code/shop-apix"); rc=$?
ok "a name that only starts like a folder is not in it" '[ "$out" = shop-apix ]'
# fallback: unknownFallsBack, fallbackTest
out=$(run project /tmp/other/); rc=$?
ok "a path on no row prints its folder name" '[ $rc = 0 ] && [ "$out" = other ]'
mkdir -p "$t/other"; echo x > "$t/other/a.ts"
out=$(run project "$t/other/a.ts"); rc=$?
ok "a file on no row prints the name of its folder" '[ "$out" = other ]'
out=$(cd "$t/other" && run project .); rc=$?
ok "a relative path on no row prints the folder name" '[ "$out" = other ]'
{ cat "$t/map.md"; printf '| shop |\n'; } > "$t/short.md"
out=$(PROJECT_MAP="$t/short.md" python3 -I "$script" list 2>&1); rc=$?
ok "a short row is skipped, with no traceback" '[ $rc = 0 ] && [[ $out != *Traceback* ]]'
# listed: unknownProject, unknownTest, listTest
out=$(run folders nope 2>/dev/null); rc=$?
ok "an unknown project lists the projects and exits 1" '[ $rc = 1 ] && [ "$out" = "shop
admin
home" ]'
out=$(run list); rc=$?
ok "list prints one line per project with its folders" '[ $rc = 0 ] && [ $(echo "$out" | wc -l) = 3 ] && [[ $out == "shop: $t/code/shop-web $t/code/shop-api"* ]]'
# read: ~ expands
out=$(run folders home); rc=$?
ok "a ~ in a folder expands to the home folder" '[ "$out" = "$HOME/zz-not-here" ]'
# no_map: noMapPrintsNothing, noMapTest
out=$(PROJECT_MAP="$t/none.md" python3 -I "$script" list 2>"$t/err"); rc=$?
ok "a missing map exits 2 and prints nothing" '[ $rc = 2 ] && [ -z "$out" ] && grep -q "no project map" "$t/err"'
echo "no table here" > "$t/empty.md"
out=$(PROJECT_MAP="$t/empty.md" python3 -I "$script" list 2>"$t/err"); rc=$?
ok "a map with no table exits 2" '[ $rc = 2 ] && [ -z "$out" ] && grep -q "no project map" "$t/err"'
# checked / unmapped: checkedQuiet, unmappedNamesFolder
out=$(run check "$t/code/shop-api/x" 2>&1); rc=$?
ok "check of a folder on the map is quiet" '[ $rc = 0 ] && [ -z "$out" ]'
out=$(run check "$t/other" 2>&1); rc=$?
ok "check of a folder on no row names it and exits 1" '[ $rc = 1 ] && [ "$out" = "not on the map: $t/other" ]'
out=$(PROJECT_MAP="$t/none.md" python3 -I "$script" check "$t/other" 2>&1); rc=$?
ok "check with no map exits 2" '[ $rc = 2 ] && [[ $out == "no project map:"* ]]'
# F4: with no PROJECT_MAP, the map is projects-mapping.md of the main checkout, also from a worktree
h="$t/harness"; mkdir -p "$h/scripts"; cp "$script" "$h/scripts/"
git -C "$h" init -q && git -C "$h" add . && git -C "$h" -c user.name=t -c user.email=t@t commit -qm x
git -C "$h" worktree add -q "$t/wt" 2>/dev/null
printf '| Project | Folder |\n|---|---|\n| shop | %s |\n' "$t/code/shop-web" > "$h/projects-mapping.md"
out=$(env -u PROJECT_MAP python3 -I "$h/scripts/project-map.py" list); rc=$?
ok "the default map is projects-mapping.md of the checkout" '[ $rc = 0 ] && [ "$out" = "shop: $t/code/shop-web" ]'
out=$(env -u PROJECT_MAP python3 -I "$t/wt/scripts/project-map.py" list); rc=$?
ok "a worktree reads the map of the main checkout" '[ $rc = 0 ] && [ "$out" = "shop: $t/code/shop-web" ]'
exit $fail
