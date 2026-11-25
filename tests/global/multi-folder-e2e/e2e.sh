#!/bin/bash
# The multi-folder e2e: real claude -p sessions, on Haiku, through project-start.sh on the
# test folders of scripts/multi-folder-fixture.sh. One `ok` or `not ok` line per check.
# By hand only: it calls a model. Model: plans/global/components/multi-folder/components/local-e2e/local-e2e.qnt.
#   E2E_MODEL=<model>  the model of the sessions, haiku by default
#   E2E_NO_MODEL=1     only the fixture checks, with no model call
root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
model=${E2E_MODEL:-haiku}
log=$(mktemp -d)
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1 (see $3)"; fail=1; fi; }

# The fixture, in a temp folder (make, madeFresh): fresh on a second run, and it never
# deletes a folder that is not its own.
tf="$log/fx"
MF_FIXTURE="$tf" bash "$root/scripts/multi-folder-fixture.sh" > /dev/null && echo old > "$tf/folder-b/stale"
MF_FIXTURE="$tf" bash "$root/scripts/multi-folder-fixture.sh" > "$log/fx.txt" 2>&1
ok fixture-fresh '[ ! -e "$tf/folder-b/stale" ] && [ -f "$tf/folder-a/web/.claude/skills/web-skill/SKILL.md" ] && grep -q "| mf-test | $(cd "$tf" && pwd -P)/kb | KB |" "$tf/projects-mapping.md"' "$log/fx.txt"
mkdir -p "$log/other" && echo keep > "$log/other/f"
MF_FIXTURE="$log/other" bash "$root/scripts/multi-folder-fixture.sh" > "$log/other.txt" 2>&1; rc=$?
ok fixture-keeps-other '[ $rc = 1 ] && [ -f "$log/other/f" ]' "$log/other.txt"
[ -n "${E2E_NO_MODEL:-}" ] && exit $fail

checks="skill-web skill-api skill-b instructions-web worktree from-folder"
d=$(bash "$root/scripts/multi-folder-fixture.sh") || { for c in $checks; do echo "not ok - $c (no test folders)"; done; exit 1; }
export PROJECT_MAP="$d/projects-mapping.md"   # never the real map (neverRealMap)

ask='List the names of every skill you have that ends in "-skill", one per line. Then use the Read tool on FILE and print its text. Then print each word that starts with MARKER- from the instructions you were given, or NONE.'

# The main checkouts: skills of each sub-repo, and the instructions of web/src.
bash "$root/scripts/project-start.sh" mf-test -p --model "$model" --allowedTools Read \
  -- "${ask/FILE/$d/folder-a/web/src/x.txt}" < /dev/null > "$log/main.txt" 2>&1
ok skill-web 'grep -q web-skill "$log/main.txt"' "$log/main.txt"
ok skill-api 'grep -q api-skill "$log/main.txt"' "$log/main.txt"
ok skill-b 'grep -q b-skill "$log/main.txt"' "$log/main.txt"
ok instructions-web 'grep -q MARKER-WEB-SRC "$log/main.txt"' "$log/main.txt"

# A worktree session: web is added as its worktree, which has its skill and its file.
w="$d/folder-a/web/.claude/worktrees/e2e"
bash "$root/scripts/project-start.sh" mf-test --worktree e2e -p --model "$model" --allowedTools Read \
  -- "${ask/FILE/$w/src/x.txt}" < /dev/null > "$log/wt.txt" 2>&1
ok worktree '[ -d "$w" ] && grep -q "added: $w" "$log/wt.txt" && grep -q web-skill "$log/wt.txt" && grep -q hello-web "$log/wt.txt" && [ -z "$(git -C "$d/folder-a/web" status --porcelain)" ] && grep -q "added: $d/folder-b/.claude/worktrees/e2e" "$log/wt.txt" && grep -qx "added: $d/kb" "$log/wt.txt"' "$log/wt.txt"

# Point at one folder (point-at-folder): at the start, --from brings the siblings on the map.
bash "$root/scripts/project-start.sh" --from "$d/folder-a/web/src" -p --model "$model" --allowedTools Read \
  -- 'List the names of every skill you have that ends in "-skill", one per line.' < /dev/null > "$log/from.txt" 2>&1
ok from-folder 'grep -qx "added: $d/folder-a/web" "$log/from.txt" && grep -q "added: $d/folder-b" "$log/from.txt" && grep -q b-skill "$log/from.txt" && grep -q web-skill "$log/from.txt"' "$log/from.txt"
exit $fail
