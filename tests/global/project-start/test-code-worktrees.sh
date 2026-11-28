#!/bin/bash
# project-start.sh --worktree: one case per part of
# plans/global/components/multi-folder/components/code-worktrees/code-worktrees.qnt.
# Real git repos, and a stub claude on PATH that prints its arguments.
root="$(cd "$(dirname "$0")/../../.." && pwd -P)"
script="$root/scripts/project-start.sh"
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
repo() { mkdir -p "$t/$1" && git -C "$t/$1" init -q && echo x > "$t/$1/x" && git -C "$t/$1" add -A \
  && git -C "$t/$1" -c user.email=t@t -c user.name=t commit -qm x; }
repo a/web; mkdir -p "$t/a/web/.claude/skills/k"; repo b; repo kb; mkdir -p "$t/plain" "$t/bin"
printf '#!/bin/bash\nfor a in "$@"; do echo "arg=$a"; done\n' > "$t/bin/claude"; chmod +x "$t/bin/claude"
cat > "$t/map.md" <<EOF
| Project | Folder | Role |
|---|---|---|
| p | $t/a/web | code |
| p | $t/b | code |
| p | $t/kb | kb |
| p | $t/plain | code |
EOF
run() { PATH="$t/bin:$PATH" PROJECT_MAP="$t/map.md" bash "$script" "$@"; }
fail=0
ok() { if eval "$2"; then echo "ok - $1"; else echo "not ok - $1, printed: [$out] err: [$(cat "$t/err")] (exit $rc)"; fail=1; fi; }
has() { grep -qx "arg=$t/$1" <<< "$out"; }
W=.claude/worktrees/e2e

out=$(run p --worktree e2e -p hi 2>"$t/err"); rc=$?
# make, noMainOfCode, startTest: each code repo is added as its worktree, on branch e2e.
ok "each code repo is added as its worktree" '[ $rc = 0 ] && has a/web/$W && has b/$W && ! has b && ! has a/web'
ok "the worktree is on branch e2e" '[ "$(git -C "$t/b/$W" branch --show-current)" = e2e ]'
# kbAndPlainKept: a KB and a folder that is no repo stay as they are.
ok "a KB, its role in any case, and a plain folder are added as they are" 'has kb && has plain && [ ! -e "$t/kb/$W" ]'
# excludedEach: the repo status stays clean.
ok "each code repo excludes its worktrees" 'grep -qx ".claude/worktrees/" "$t/b/.git/info/exclude" && [ -z "$(git -C "$t/b" status --porcelain)" ]'
# start: the folders are printed, and the other arguments go to claude.
ok "the added folders are printed" 'grep -q "added: $t/b/$W" "$t/err"'
ok "the other arguments go to claude" '[[ $out == *"arg=-p
arg=hi" ]]'
# initWith an existing worktree: a second run reuses it.
out=$(run p --worktree e2e 2>"$t/err"); rc=$?
ok "a second run reuses the worktree" '[ $rc = 0 ] && has b/$W && [ $(grep -cx ".claude/worktrees/" "$t/b/.git/info/exclude") = 1 ]'
# neverDeletes: both worktrees are still there.
ok "nothing is deleted" '[ $(git -C "$t/b" worktree list | wc -l) = 2 ] && git -C "$t/b" rev-parse -q --verify e2e >/dev/null'
# make, the failed add: a branch checked out in another worktree stops the script before claude.
git -C "$t/b" worktree add -q -b busy "$t/busy" 2>/dev/null
out=$(run p --worktree busy 2>"$t/err"); rc=$?
ok "a failed worktree add names the repo and starts nothing" '[ $rc = 1 ] && [ -z "$out" ] && grep -q "worktree add failed: $t/b" "$t/err"'
exit $fail
