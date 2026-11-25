#!/bin/bash
# Make the test folders of the multi-folder e2e, fresh, and print their path:
#
#   folder-a/web, folder-a/api   two code repos in a folder that is no repo
#   folder-b                     one code repo
#   kb                           a KB
#   projects-mapping.md          the map of the project mf-test, for PROJECT_MAP
#
# Each code repo has its own skill, <name>-skill, and a src/CLAUDE.md. That of
# folder-a/web holds the marker MARKER-WEB-SRC. Each repo's top CLAUDE.md holds a fake
# passcode, and CHECKS.md lists what to ask a session and what it must answer. The folder is $MF_FIXTURE, else ~/second-brain/test-folders.
# It deletes an old folder only if it holds the .mf-fixture mark of an earlier run.
# Plan: plans/global/components/multi-folder/components/local-e2e/.
set -euo pipefail
d=${MF_FIXTURE:-$HOME/second-brain/test-folders}
if [ -e "$d" ]; then
  [ -f "$d/.mf-fixture" ] || { echo "not a test folder, left as it is: $d" >&2; exit 1; }
  rm -rf "$d"
fi
mkdir -p "$d"; d=$(cd "$d" && pwd -P); touch "$d/.mf-fixture"

skill() {  # skill <folder> <name>
  mkdir -p "$1/.claude/skills/$2"
  printf -- '---\nname: %s\ndescription: Test skill %s of the multi-folder e2e. Use only when asked about it.\n---\nSay %s-OK.\n' "$2" "$2" "$2" \
    > "$1/.claude/skills/$2/SKILL.md"
}
repo() {   # repo <folder>: a git repo with one commit of what it holds
  git -C "$1" init -q
  git -C "$1" add -A
  git -C "$1" -c user.name=e2e -c user.email=t@t commit -qm "test folder"
}

mkdir -p "$d/folder-a/web/src" "$d/folder-a/api" "$d/folder-b" "$d/kb"
skill "$d/folder-a/web" web-skill
echo "Instructions of the web source: the marker is MARKER-WEB-SRC." > "$d/folder-a/web/src/CLAUDE.md"
echo "hello-web" > "$d/folder-a/web/src/x.txt"
echo "# Web repo. Fake passcode for tests: PASSCODE-WEB-4417." > "$d/folder-a/web/CLAUDE.md"
repo "$d/folder-a/web"
for r in folder-a/api:api:API-8823 folder-b:b:B-1590; do
  f="$d/${r%%:*}"; n=${r#*:}; code=${n#*:}; n=${n%%:*}
  skill "$f" "$n-skill"
  mkdir -p "$f/src"; echo "Instructions of the $n source." > "$f/src/CLAUDE.md"
  echo "# Repo $n. Fake passcode for tests: PASSCODE-$code." > "$f/CLAUDE.md"
  repo "$f"
done
echo "# Test KB. The marker is MARKER-KB. Fake passcode for tests: PASSCODE-KB-6062." > "$d/kb/CLAUDE.md"
echo "# A page" > "$d/kb/page.md"
repo "$d/kb"

cat > "$d/projects-mapping.md" <<EOF
| Project | Folder | Role | KB | Note |
|---|---|---|---|---|
| mf-test | $d/folder-a/web | frontend | kb | the web code repo of folder A |
| mf-test | $d/folder-a/api | backend | kb | the api code repo of folder A |
| mf-test | $d/folder-b | backend | kb | one code repo |
| mf-test | $d/kb | KB | kb | the test KB |
EOF
cat > "$d/CHECKS.md" <<'CHECKS'
# Checks for the test folders

Start a session on them: pick `mf-both` in the domains pane (`/domains`), or run
`bash ~/second-brain/harness/scripts/project-start.sh mf-test`. Then ask the session each
question. The passcodes are fake: each one sits only in the CLAUDE.md of its folder.

| Ask | A good answer | Shows |
|---|---|---|
| What fake passcodes do your instructions hold? | PASSCODE-WEB-4417, PASSCODE-API-8823, PASSCODE-B-1590, PASSCODE-KB-6062 | the CLAUDE.md of each added folder loads |
| Which skills end in -skill? | web-skill, api-skill, b-skill | the skills of each added folder load |
| What does folder-a/web/src/x.txt say? | hello-web | the session can read the folders |
| Read folder-a/web/src/x.txt, then name the MARKER- words you were given. | MARKER-WEB-SRC, MARKER-KB | a subfolder's CLAUDE.md loads on a read |

With `--worktree <name>`, the web, api and b answers come from the worktrees, and the status line shows the worktree name.
CHECKS
echo "$d"
