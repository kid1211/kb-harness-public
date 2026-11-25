#!/bin/bash
# project-start.sh --from <folder>: one case per run and invariant of
# plans/global/components/multi-folder/components/point-at-folder/point-at-folder.qnt, the start side.
# A stub claude on PATH prints its arguments.
root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
script="$root/scripts/project-start.sh"
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/a/web/src/lib/.claude/skills/l" "$t/a/web/src/lib/util" "$t/b" "$t/kb" "$t/x" "$t/bin"
git -C "$t/a/web" init -q
printf '#!/bin/bash\nfor a in "$@"; do echo "arg=$a"; done\n' > "$t/bin/claude"; chmod +x "$t/bin/claude"
printf '| Project | Folder | Role |\n|---|---|---|\n| p | %s/a | code |\n| p | %s/b | code |\n| p | %s/kb | KB |\n' "$t" "$t" "$t" > "$t/map.md"
run() { PATH="$t/bin:$PATH" PROJECT_MAP="$t/map.md" bash "$script" "$@"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out] err: [$(cat "$t/err")] (exit $rc)"; fail=1; fi; }
has() { grep -qx "arg=$t/$1" <<< "$out"; }

# start, startAddsSiblings, startTest
out=$(run --from "$t/a/web/src/lib/util" -p hi 2>"$t/err"); rc=$?
ok "a deep folder starts its project with each sibling" '[ $rc = 0 ] && has a && has b && has kb'
# startAddsRoot: the git root of the folder is added, and nothing below it.
ok "the git root of the folder is added, not the folders below it" 'has a/web && ! has a/web/src/lib && ! has a/web/src/lib/util'
ok "the other arguments go to claude" '[[ $out == *"arg=-p
arg=hi" ]]'
# unmapped, unmappedAsks, unmappedTest
out=$(run --from "$t/x" 2>"$t/err"); rc=$?
ok "a folder on no row starts nothing and asks for a row" '[ $rc = 1 ] && [ -z "$out" ] && grep -q "not on the map: $t/x" "$t/err" && grep -q "Add a row for it to $t/map.md" "$t/err" && grep -qx "p: .*" "$t/err"'
out=$(PATH="$t/bin:$PATH" PROJECT_MAP="$t/none.md" bash "$script" --from "$t/a" 2>"$t/err"); rc=$?
ok "a missing map says so, and asks for no row" '[ $rc = 2 ] && [ -z "$out" ] && grep -q "no project map" "$t/err" && ! grep -q "Add a row" "$t/err"'
out=$(run --from "" 2>"$t/err"); rc=$?
ok "an empty folder name starts nothing" '[ $rc = 64 ] && [ -z "$out" ]'

# startTest: the list is exact, one --add-dir per folder.
out=$(run --from "$t/a/web/src/lib/util" 2>"$t/err")
ok "a start adds exactly the siblings and the git root" '[ "$(grep -c "^arg=--add-dir" <<< "$out")" = 4 ]'

# --from with --worktree (F1): the code repo of the git root goes by its worktree.
g() { git -C "$1" -c user.name=t -c user.email=t@t "${@:2}"; }
echo x > "$t/a/web/f"; g "$t/a/web" add f; g "$t/a/web" commit -qm x
out=$(run --from "$t/a/web/src" --worktree w 2>"$t/err"); rc=$?
ok "--from with --worktree adds the worktree of the git root" '[ $rc = 0 ] && has a/web/.claude/worktrees/w && ! has a/web && has kb'
# The git root above a KB row takes the role of that row: no worktree in a KB repo.
mkdir -p "$t/r/kbsub/x"; g "$t/r" init -q; echo x > "$t/r/f"; g "$t/r" add f; g "$t/r" commit -qm x
printf '| Project | Folder | Role |\n|---|---|---|\n| q | %s/r/kbsub | KB |\n' "$t" > "$t/map2.md"
out=$(PATH="$t/bin:$PATH" PROJECT_MAP="$t/map2.md" bash "$script" --from "$t/r/kbsub/x" --worktree w 2>"$t/err"); rc=$?
ok "a git root above a KB row gets no worktree" '[ $rc = 0 ] && has r && [ ! -e "$t/r/.claude/worktrees/w" ]'
# A row by a symlink path still gives its role.
ln -s "$t/r" "$t/rl"
printf '| Project | Folder | Role |\n|---|---|---|\n| q | %s/rl/kbsub | KB |\n' "$t" > "$t/map3.md"
out=$(PATH="$t/bin:$PATH" PROJECT_MAP="$t/map3.md" bash "$script" --from "$t/r/kbsub/x" --worktree w2 2>"$t/err"); rc=$?
ok "a row by a symlink path gives its role" '[ $rc = 0 ] && [ ! -e "$t/r/.claude/worktrees/w2" ]'
exit $fail
