#!/usr/bin/env bash
# branch-guard.sh: a new branch in the main checkout of the harness is refused, git switch
# is refused everywhere, and each other call passes or fails open
# (plans/global/components/hooks/components/branch-guard). One case per run and invariant
# of branch-guard.qnt, then the parse cases of 1-design.md, Build checks.
# Usage: test-branch-guard.sh [-v]
set -u
repo="$(cd "$(dirname "$0")/../../.." && pwd -P)"
hook="$repo/.claude/hooks/branch-guard.sh"
V=0; [[ "${1:-}" == -v ]] && V=1
pass=0 fail=0
ok()  { pass=$((pass + 1)); (( V )) && echo "ok   $1"; return 0; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }

t="$(mktemp -d)"; t="$(cd "$t" && pwd -P)"
trap 'rm -rf "$t"' EXIT
g() { git -c init.defaultBranch=main -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null 2>&1; }

# Fixtures: an origin with branches only it has, the harness H with a linked worktree W,
# and a KB K, whose skills folder is a symlink, with a linked worktree KW.
g init -q --bare "$t/O"
g init -q "$t/H"
mkdir -p "$t/H/.claude/skills" "$t/H/scripts"
touch "$t/H/.claude/skills/.keep"; printf '#!/bin/sh\n' > "$t/H/scripts/link-kb.sh"
g -C "$t/H" add -A; g -C "$t/H" commit -qm init; g -C "$t/H" tag v1
g -C "$t/H" branch loc
g -C "$t/H" remote add origin "$t/O"
g -C "$t/H" push -q origin main main:ronly main:pre/x
g -C "$t/H" fetch -q origin
g -C "$t/H" remote set-head origin main
g -C "$t/H" worktree add -q "$t/W" -b wtb
g init -q "$t/K"
mkdir -p "$t/K/.claude"; ln -s "$t/H/.claude/skills" "$t/K/.claude/skills"
g -C "$t/K" add -A; g -C "$t/K" commit -qm init
g -C "$t/K" worktree add -q "$t/KW" -b kwb
mkdir -p "$t/out"
H="$t/H" W="$t/W" K="$t/K" KW="$t/KW"

out="" code=0
call() {  # <cwd> <command> [env...]: runs the hook, sets $code and $out
  local d="$1" c="$2"; shift 2
  out="$(jq -n --arg c "$c" --arg d "$d" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' \
    | env "$@" "$hook" 2>&1 >/dev/null)"; code=$?
  case "$code" in 0|2) ;; *) bad "exitIsZeroOrTwo: exit $code for '$c'" ;; esac
}
raw() {  # <stdin text>: runs the hook on raw stdin
  out="$(printf '%s' "$1" | "$hook" 2>&1 >/dev/null)"; code=$?
}
# <name> <want exit> <stderr: quiet | warn | any | text it holds> <cwd> <command> [env...]
check() {
  local n="$1" want="$2" err="$3"; shift 3
  call "$@"
  if [[ "$code" != "$want" ]]; then bad "$n: exit $code, want $want: $out"; return; fi
  case "$err" in
    any) ;;
    quiet) [[ -z "$out" ]] || { bad "$n: stderr not empty: $out"; return; } ;;
    warn) [[ "$out" == branch-guard:* ]] || { bad "$n: no warning: $out"; return; } ;;
    *) [[ "$out" == *"$err"* ]] || { bad "$n: stderr lacks '$err': $out"; return; } ;;
  esac
  ok "$n"
}
refused() { check "$1 refused" 2 any "$2" "$1" "${@:3}"; }
passes()  { check "$1 passes" 0 quiet "$2" "$1" "${@:3}"; }

# --- One case per run and invariant of the model ---
check "switchInKbTest: git switch in a KB" 2 "git checkout" "$K" "git switch x"
check "switchNewInMainTest: git switch -c in the main checkout" 2 EnterWorktree "$H" "git switch -c x"
[[ "$out" == *EnterWorktree* && "$out" != *"git checkout"* ]] && ok "messageFits: only EnterWorktree" || bad "messageFits: $out"
check "switchNew in the KB names git checkout" 2 "git checkout" "$K" "git switch -c x"
for c in "git branch x" "git checkout -b x" "git stash branch x" "git checkout ronly"; do
  check "branchInMainTest: $c" 2 EnterWorktree "$H" "$c"
  check "branchInWorktreeTest: $c" 0 quiet "$W" "$c"
done
check "remoteOnlyTest: a name only a remote has" 2 EnterWorktree "$H" "git checkout ronly"
for c in "git checkout loc" "git checkout v1" "git checkout -" "git checkout origin/ronly" "git checkout -- f"; do
  passes "$c" "$H"
done
land="$(sed -n 's/^ *\(\[ -z "\$(git status --porcelain)" \].*NOT_LANDED\)$/\1/p' "$repo/.claude/skills/worktree-end/SKILL.md")"
[[ -n "$land" ]] && ok "found the landing line of worktree-end" || bad "no landing line in worktree-end"
check "unreadableNameTest: the landing line of worktree-end" 0 quiet "$H" "$land"
check "branchInKbTest: in the KB" 0 quiet "$K" "git checkout -b x"
check "branchInKbTest: in the KB worktree" 0 quiet "$KW" "git checkout -b x"
check "gitErrorTest: a cwd outside a repo" 2 "branch-guard:" "$t/out" "git branch y; git -C $H branch x"
[[ "$out" == *EnterWorktree* && "$(grep -c '^branch-guard:' <<< "$out")" == 2 ]] \
  && ok "gitErrorWarns: a warning, then the refusal" || bad "gitErrorWarns: $out"
check "gitErrorTest: a branch outside a repo passes" 0 warn "$t/out" "git branch y"
raw "{not json git"; [[ "$code" == 0 && "$out" == branch-guard:* ]] && ok "badInputTest: bad JSON" || bad "badInputTest: bad JSON: $code $out"
raw '{"tool_input":{},"cwd":"/","x":"git"}'; [[ "$code" == 0 && "$out" == branch-guard:* ]] && ok "badInputTest: no command" || bad "badInputTest: no command: $code $out"
for c in "git worktree add -b n ../n" "git worktree add -B n ../n" "git worktree add ../n ronly"; do
  check "worktreeAddTest: $c in the main checkout" 0 quiet "$H" "$c"
  check "worktreeAddTest: $c in the worktree" 0 quiet "$W" "$c"
  check "worktreeAddTest: $c in the KB" 0 quiet "$K" "$c"
done
check "quickExitTest: ls" 0 quiet "$H" "ls"
raw "{not json"; [[ "$code" == 0 && -z "$out" ]] && ok "quietWithoutGit: bad JSON with no git" || bad "quietWithoutGit: $code $out"
check "noGitPartTest: echo \"git switch\"" 0 quiet "$H" 'echo "git switch"'
check "failsOpen: an open quote" 0 warn "$H" "echo it's; git switch x"
mkdir -p "$t/bin"; printf '#!/bin/sh\ncat >/dev/null\nexit 1\n' > "$t/bin/python3"; chmod +x "$t/bin/python3"
check "crashTest: python3 exits 1" 0 warn "$H" "git switch x" PATH="$t/bin:$PATH"

# --- The parse: one case per word of R23 and R24 ---
for a in "-b x" "-B x" "--orphan x" "--track origin/x" "-t origin/x" "-qb x" "-bx" "--orph x" \
         "--or x" "--orphan=x" "--tr origin/x" "--track=direct origin/x"; do
  refused "git checkout $a" "$H"
done
for a in "x" "x -f" "-f x" "--force x" "-m a b" "-M a" "--move a b" "-c a b" "-C a b" "--copy a b" \
         "-v x" "--sort=x y" "--format '%(refname)' x"; do
  refused "git branch $a" "$H"
done
for a in "" "--list" "--list 'foo*'" "-l" "-a" "-r" "-v" "-vv" "--contains main" "--no-contains main" \
         "--merged main" "--no-merged main" "--points-at HEAD" "--sort=-committerdate" \
         "--sort -committerdate" "--format '%(refname)'" "--format=%(refname)" "--column" \
         "--show-current" "-d x" "-D x" "--delete x" "--del x" "--mer main" "-u origin/x" \
         "--set-upstream-to=origin/x" "--unset-upstream" "--edit-description"; do
  check "git branch $a passes" 0 any "$H" "git branch $a"
done
for c in "git checkout -- file" "git checkout main -- file" "git checkout HEAD -- file" "git checkout HEAD" "git checkout pre"; do
  passes "$c" "$H"
done
refused "ls  # list"$'\n'"git checkout -b x" "$H"
refused "git \\"$'\n'"checkout -b x" "$H"
refused "(cd $K && ls); git checkout -b x" "$H"
refused "make |& git switch y" "$H"
refused "(cd $K && git pull) ; git checkout -b x" "$H"
refused "cd $H && bash -c 'git branch x'" "$K"
for w in "timeout 30" "nice" "env -i" "time -p"; do refused "$w git switch x" "$H"; done
passes "cat > n.md <<EOF"$'\n'"Don't use git switch"$'\n'"EOF" "$H"
refused "cat <<< x"$'\n'"git switch y" "$H"
refused "git -C $H branch x" "$K"
refused "GIT_DIR=$H/.git git branch x" "$K"
refused "git --git-dir $H/.git branch x" "$K"
passes "GIT_DIR=$H/.git/worktrees/W git branch x" "$K"
refused "cd $H && git branch x" "$K"
refused "cd ~/H && git branch x" "$K" HOME="$t"
refused "(cd $H && git branch x)" "$K"
refused "a && git checkout -b x" "$H"
refused "sleep 1 & git checkout -b x" "$H"
refused "ls"$'\n'"git checkout -b x" "$H"
for c in "bash -c 'git checkout -b x'" "bash -lc 'git checkout -b x'" "/bin/sh -c \"git switch y\"" "zsh -c 'git checkout -b x'"; do
  refused "$c" "$H"
done
for c in "command git switch x" "env GIT_DIR=x git switch y" "/usr/bin/git switch x" "if true; then git switch x; fi" "{ git switch x; }"; do
  refused "$c" "$H"
done
for c in "git -c core.x=y checkout -b x" "git --no-pager switch x" "git -P switch x"; do refused "$c" "$H"; done
refused "git checkout ronly 2>/dev/null" "$H"
refused "git checkout -q ronly" "$H"
passes "cat > n.md <<'EOF'"$'\n'"git switch main"$'\n'"EOF" "$H"
passes "git -C \"\$H\" checkout -b x" "$K"
for c in "git branch -- x" "git --attr-source HEAD checkout -b x" "git --config-env a=B checkout -b x"; do refused "$c" "$H"; done
refused "GIT_DIR=.git git -C $H branch x" "$K"
refused "timeout --signal KILL 30 git switch x" "$H"
refused 'echo $((1<<2))'$'\n'"git switch x" "$H"
refused '(( n = 1 << 3 ))'$'\n'"git switch x" "$H"
refused 'cat <<\EOF'$'\n'"x"$'\n'"EOF"$'\n'"git checkout -b x" "$H"
passes "cd $H && GIT_DIR=\"\$X\" git branch x" "$K"
passes "git commit -m \"\$(cat <<'EOF'"$'\n''Hook: refuse "cd x && git switch y"'$'\n'"EOF"$'\n'")\"" "$H"
refused "echo \$'it\\'s'; git switch x" "$H"
refused 'echo "$(ls # it'"'"'s'$'\n'')"'$'\n'"git switch x" "$H"
refused 'echo "$(cat <<< "a"'$'\n'')"'$'\n'"git switch x" "$H"
check "unreadableGitErrorTest: an unreadable name outside a repo" 0 quiet "$t/out" 'git checkout "$X"'

# --- The settings line and the CLAUDE.md line ---
cmd="$(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | select(any(.hooks[]; .command | test("branch-guard.sh"))) | .hooks[] | select(.command | test("branch-guard.sh")) | .command' "$repo/.claude/settings.json")"
iff="$(jq -r '.hooks.PreToolUse[] | .hooks[] | select(.command | test("branch-guard.sh")) | .if // empty' "$repo/.claude/settings.json")"
[[ -n "$cmd" && -z "$iff" && "$cmd" == *CLAUDE_PROJECT_DIR* ]] \
  && ok "settings.json: a Bash entry, no if, the fall back" || bad "settings.json entry: '$cmd' if='$iff'"
if [[ -n "$cmd" ]]; then
  json="$(jq -n --arg d "$K" '{tool_input:{command:"git switch x"},cwd:$d}')"
  (cd "$t/out" && printf '%s' "$json" | CLAUDE_PROJECT_DIR="$repo" sh -c "$cmd" >/dev/null 2>&1); code=$?
  [[ "$code" == 2 ]] && ok "the settings line falls back to the project folder" || bad "the fall back: exit $code"
fi
# The public copy holds neither CLAUDE.md, so it skips these two.
if [[ -f "$repo/.claude/CLAUDE.md" ]]; then
  sec="$(sed -n '/^## Branches and worktrees: harness only/,/^## /p' "$repo/.claude/CLAUDE.md")"
  [[ "$sec" == *"only with a worktree"* ]] && ok ".claude/CLAUDE.md: a harness branch only with a worktree" \
    || bad ".claude/CLAUDE.md lacks 'only with a worktree' in Branches and worktrees"
else echo "skip .claude/CLAUDE.md: not in this checkout"; fi

if [[ -f "$repo/CLAUDE.md" ]]; then
  grep -q '^bash tests/global/hooks/test-branch-guard.sh ' "$repo/CLAUDE.md" \
    && ok "CLAUDE.md: the suite is in the Tests list" || bad "CLAUDE.md: the suite is not in the Tests list"
else echo "skip CLAUDE.md: not in this checkout"; fi

echo "branch-guard: $pass passed, $fail failed"
(( fail == 0 ))
