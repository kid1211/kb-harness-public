#!/bin/bash
# nested-instructions.sh: one case per run and invariant of
# plans/global/components/multi-folder/components/nested-instructions/nested-instructions.qnt.
# A throwaway start folder, a throwaway git repo outside it, and a throwaway session folder.
root="$(cd "$(dirname "$0")/../../.." && pwd)"
hook="$root/.claude/hooks/nested-instructions.sh"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/start" "$t/repo/web/src" "$t/tmp"
git init -q "$t/repo"
echo "top rules" > "$t/repo/CLAUDE.md"
echo "web rules" > "$t/repo/web/CLAUDE.md"
echo "src rules" > "$t/repo/web/src/CLAUDE.md"
echo "start rules" > "$t/start/CLAUDE.md"
touch "$t/repo/web/src/a.ts" "$t/repo/web/b.ts" "$t/start/x.md"
repo=$(cd "$t/repo" && pwd -P)
# The repo is added in sessions s1, s2 and s9.
for s in s1 s2 s9; do mkdir -p "$t/state/$s"; echo "$repo" > "$t/state/$s/dirs"; done
call() { printf '{"session_id":"%s","cwd":"%s","tool_name":"Read","tool_input":{"file_path":"%s"}}' "$1" "$t/start" "$2" \
  | CLAUDE_MULTI_FOLDER_STATE="$t/state" bash "$hook"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out] (exit $rc)"; fail=1; fi; }

# given: walk, give, givenAbove, deepTest
out=$(call s1 "$t/repo/web/src/a.ts"); rc=$?
ok "a deep file outside gives both CLAUDE.md files below the repo top" '[ $rc = 0 ] && [[ $out == *"web rules"* ]] && [[ $out == *"src rules"* ]]'
ok "the CLAUDE.md of the repo top is left out" '[[ $out == *"web rules"* ]] && [[ $out != *"top rules"* ]]'
ok "the higher one comes first" 'w=${out%%web rules*}; s=${out%%src rules*}; [ ${#w} -lt ${#s} ]'
ok "the output is PostToolUse JSON with additionalContext" 'python3 -I -c "import json,sys; h=json.loads(sys.argv[1])[\"hookSpecificOutput\"]; assert h[\"hookEventName\"]==\"PostToolUse\" and \"Instructions from\" in h[\"additionalContext\"]" "$out"'
# silent: nothingNew, onlyNew, onceTest
out=$(call s1 "$t/repo/web/b.ts"); rc=$?
ok "a second file of the same repo gives nothing new" '[ $rc = 0 ] && [ -z "$out" ]'
out=$(call s2 "$t/repo/web/b.ts"); rc=$?
ok "a new session gets the file again" '[[ $out == *"web rules"* ]] && [[ $out != *"src rules"* ]]'
# silent: inside, insideSilent, insideTest
out=$(call s3 "$t/start/x.md"); rc=$?
ok "a file in the start folder gives nothing" '[ $rc = 0 ] && [ -z "$out" ]'
ln -s "$t/repo/web" "$t/start/link"
out=$(call s5 "$t/start/link/src/a.ts"); rc=$?
ok "a file the start folder reaches by a symlink gives nothing" '[ $rc = 0 ] && [ -z "$out" ]'
# silent: a CLAUDE.md above the start folder loads already
out=$(printf '{"session_id":"s6","cwd":"%s","tool_input":{"file_path":"%s"}}' "$t/repo/web/src" "$t/repo/web/b.ts" | CLAUDE_MULTI_FOLDER_STATE="$t/state" bash "$hook"); rc=$?
ok "a CLAUDE.md in a folder above the start folder is left out" '[ $rc = 0 ] && [ -z "$out" ]'
# walk with no repo: it stops at $HOME
mkdir -p "$t/home/notes/sub"; echo "notes rules" > "$t/home/notes/CLAUDE.md"; echo "home rules" > "$t/home/CLAUDE.md"
out=$(printf '{"session_id":"s7","cwd":"%s","tool_input":{"file_path":"%s"}}' "$t/start" "$t/home/notes/sub/n.md" | HOME="$t/home" CLAUDE_MULTI_FOLDER_STATE="$t/state" bash "$hook"); rc=$?
ok "with no repo the walk stops below \$HOME" '[[ $out == *"notes rules"* ]] && [[ $out != *"home rules"* ]]'
# given: notAddedTest, a repo not added gives its top file too
out=$(call s8 "$t/repo/web/b.ts"); rc=$?
ok "a file in a repo not added gives the top CLAUDE.md too" '[[ $out == *"top rules"* ]] && [[ $out == *"web rules"* ]]'
ok "the given files go to the session file with who gave them" 'grep -q "^$repo/CLAUDE.md	hook\$" "$t/state/s8/instructions"'
# noted: note, neverLoaded, loadedTest
out=$(printf '{"session_id":"s9","cwd":"%s","hook_event_name":"InstructionsLoaded","file_path":"%s","load_reason":"nested_traversal"}' "$t/start" "$repo/web/src/CLAUDE.md" | CLAUDE_MULTI_FOLDER_STATE="$t/state" bash "$hook"); rc=$?
ok "an InstructionsLoaded event is noted, with no output" '[ $rc = 0 ] && [ -z "$out" ] && grep -q "^$repo/web/src/CLAUDE.md	nested_traversal\$" "$t/state/s9/instructions"'
out=$(call s9 "$t/repo/web/src/a.ts"); rc=$?
ok "a CLAUDE.md that Claude Code loaded is not given" '[[ $out == *"web rules"* ]] && [[ $out != *"src rules"* ]]'
# F4: never blocks
out=$(echo 'not json' | CLAUDE_MULTI_FOLDER_STATE="$t/state" bash "$hook"); rc=$?
ok "bad input exits 0 with no output" '[ $rc = 0 ] && [ -z "$out" ]'
out=$(echo '{"session_id":"s4","cwd":"/x","tool_input":{}}' | CLAUDE_MULTI_FOLDER_STATE="$t/state" bash "$hook"); rc=$?
ok "no file path exits 0 with no output" '[ $rc = 0 ] && [ -z "$out" ]'
# wiring
for tool in Read Edit Write; do
  ok "settings run the hook after $tool" 'python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); assert any(sys.argv[2] in e[\"matcher\"].split(\"|\") and any(\"nested-instructions.sh\" in h[\"command\"] for h in e[\"hooks\"]) for e in d[\"hooks\"][\"PostToolUse\"])" "$root/.claude/settings.json" '$tool''
done
ok "settings run the hook on InstructionsLoaded" 'python3 -I -c "import json,sys; d=json.load(open(sys.argv[1])); assert any(\"nested-instructions.sh\" in h[\"command\"] for e in d[\"hooks\"][\"InstructionsLoaded\"] for h in e[\"hooks\"])" "$root/.claude/settings.json"'
exit $fail
