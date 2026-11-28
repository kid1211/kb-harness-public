#!/bin/bash
# scripts/statusline.sh: the folder, a red wt- in a worktree, the model, the context use, no
# branch, and the domain last. Run through a link, as ~/.claude/statusline.sh runs it.
# Plan: plans/global/components/multi-folder/components/folder-status/.
root="$(cd "$(dirname "$0")/../../.." && pwd)"
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
ln -s "$root/scripts/statusline.sh" "$t/statusline.sh"
mkdir -p "$t/repo/kb" "$t/plain"
git -C "$t/repo" init -q -b trunk
git -C "$t/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m x
git -C "$t/repo" worktree add -q -b side "$t/repo-wt" 2>/dev/null
cat > "$t/map.md" <<EOF
| Project | Folder | Role | KB | Note |
|---|---|---|---|---|
| notes | $t/repo/kb | KB | kb | a test domain |
EOF
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out]"; fail=1; fi; }
run() {
  jq -n --arg d "$1" --argjson a "$2" '{session_id: "s1", workspace: {current_dir: $d, added_dirs: $a},
    model: {display_name: "Opus"}, context_window: {context_window_size: 200000,
    current_usage: {input_tokens: 50000, cache_creation_input_tokens: 0, cache_read_input_tokens: 0},
    total_input_tokens: 1, total_output_tokens: 1}}' |
    PROJECT_MAP="$t/map.md" CLAUDE_MULTI_FOLDER_STATE="$t/st" STATUSLINE_STATE_FILE="$t/state" bash "$t/statusline.sh" |
    sed $'s/\x1b\\[[0-9;]*m//g'
}

out=$(run "$t/repo" '[]'); rc=$?
ok "the folder, the model, the context use and no domain, in that order" '[ $rc = 0 ] && [ "$out" = "repo | Opus | CTX: 25% | no domain" ]'
ok "no branch name" '[[ $out != *trunk* ]]'
out=$(run "$t/repo-wt" '[]')
ok "a worktree shows wt- and the name of its main checkout" '[[ $out == "wt-repo | Opus |"* ]] && [[ $out != *side* ]]'
out=$(run "$t/plain" "[\"$t/repo/kb\"]")
ok "the domain of the added folders, last, found through the link" '[[ $out == *"| notes" ]]'
exit $fail
