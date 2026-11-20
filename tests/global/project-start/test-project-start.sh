#!/bin/bash
# project-start.sh: one case per state of
# plans/global/components/multi-folder/components/project-start/project-start.qnt.
# A stub claude on PATH prints its folder and its arguments.
root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
script="$root/scripts/project-start.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/code/web" "$t/code/api" "$t/bin"
printf '#!/bin/bash\necho "cwd=$PWD"\nfor a in "$@"; do echo "arg=$a"; done\n' > "$t/bin/claude"; chmod +x "$t/bin/claude"
cat > "$t/map.md" <<EOF
| Project | Folder |
|---|---|
| shop | $t/code/web |
| shop | $t/code/api |
| shop | $t/code/gone |
| shop | $root |
EOF
run() { PATH="$t/bin:$PATH" PROJECT_MAP="$t/map.md" bash "$script" "$@"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out] err: [$(cat "$t/err")] (exit $rc)"; fail=1; fi; }

# started: addedOfProject, startTest
out=$(run shop 2>"$t/err"); rc=$?
ok "a known project runs claude in the harness" '[ $rc = 0 ] && [[ $out == "cwd=$root"* ]]'
ok "each folder on disk is added" '[[ $out == *"arg=--add-dir
arg=$t/code/web
arg=--add-dir
arg=$t/code/api"* ]]'
# check: addedOnDisk
ok "a missing folder is named and left out" 'grep -q "missing: $t/code/gone" "$t/err" && [[ $out != *gone* ]]'
ok "the harness itself is not added" '[[ $out == *cwd=* ]] && [ $(grep -c "^arg=$root\$" <<< "$out") = 0 ]'
# asked: extra arguments
out=$(run shop --model haiku 2>"$t/err"); rc=$?
ok "extra arguments go to claude after the folders" '[[ $out == *"arg=$t/code/api
arg=--model
arg=haiku" ]]'
# unknown: unknownAddsNothing, unknownTest
out=$(run nope 2>"$t/err"); rc=$?
ok "an unknown project exits 1 and does not run claude" '[ $rc = 1 ] && [[ $out != *cwd=* ]] && grep -q "unknown project: nope" "$t/err" && grep -q "^shop$" "$t/err"'
out=$(run 2>"$t/err"); rc=$?
ok "no name prints the usage and exits 64" '[ $rc = 64 ] && [[ $out != *cwd=* ]]'
exit $fail
