#!/usr/bin/env bash
# Tests of op-fork-keep and op-fork-new-wt (plans/op-skills). Stub `cmux` and
# `claude` on PATH, a throwaway repo with a linked worktree. Runs each skill in the
# main checkout, in the worktree, and in a session that entered the worktree after
# it started (R20).
set -u
fork="$(cd "$(dirname "$0")/../../.." && pwd)/.claude/skills/op-fork-keep/scripts/fork.sh"
T=$(mktemp -d); trap 'pkill -f -- "--resume $SID" 2>/dev/null; rm -rf "$T"' EXIT
SID="ab12cd34-test-$$"
pass=0 failn=0
ok()  { pass=$((pass + 1)); [ -z "${V:-}" ] || echo "ok   $1"; }
bad() { failn=$((failn + 1)); echo "FAIL $1"; }

mkdir -p "$T/bin" "$T/repo" "$T/nogit"
cat > "$T/bin/cmux" <<'EOF'
#!/usr/bin/env bash
f=$STUB/panes; n=$(cat "$f" 2>/dev/null || echo 1)
case $1 in
  list-panes) for i in $(seq "$n"); do echo "  pane:$i"; done ;;
  new-split) [ "${FAIL_SPLIT:-}" ] && exit 1; echo $((n + 1)) > "$f"; echo "OK surface:9$n workspace:1" ;;
  send) [ "${FAIL_SEND:-}" ] && exit 1; cd "${PANE_START:-/}"; CMD=${4%\\n} bash -c 'eval "$CMD"' >/dev/null 2>&1 & ;;
  close-surface) echo $((n - 1)) > "$f"; pkill -f -- "--resume $SID_FOR_STUB" ;;
esac
EOF
# With -w <name>, the stub makes the worktree as claude does: in the main
# checkout's .claude/worktrees/, on worktree-<name>, from main. Then it runs there.
cat > "$T/bin/claude" <<'EOF'
#!/usr/bin/env bash
[ "${FAIL_CLAUDE:-}" ] && exit 1
args="$*"
while [ $# -gt 0 ]; do
  if [ "$1" = -w ]; then
    main=$(cd "$(git rev-parse --path-format=absolute --git-common-dir)/.." && pwd -P)
    git worktree add -q -b "worktree-$2" "$main/.claude/worktrees/$2" main || exit 1
    cd "$main/.claude/worktrees/$2"
  fi
  shift
done
[ "${FAIL_AFTER_WT:-}" ] && exit 1
exec -a "claude $args" sleep 30
EOF
chmod +x "$T/bin/"*

git -C "$T/repo" init -q -b main && git -C "$T/repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$T/repo" worktree add -q -b wt "$T/repo/.claude/worktrees/wt"
main=$(cd "$T/repo" && pwd -P); wt=$(cd "$T/repo/.claude/worktrees/wt" && pwd -P)

run() { # $1: directory, then the args of fork.sh. Prints the output and sets $rc.
  local d=$1; shift
  out=$(cd "$d" && PATH="$T/bin:$PATH" STUB="$T" SID_FOR_STUB="$SID" CLAUDE_CODE_SESSION_ID="$SID" \
        CMUX_SURFACE_ID=surface:1 bash "$fork" "$@" 2>&1); rc=$?
}
fork_cwd() { local p; p=$(pgrep -f -- "--resume $SID --fork-session" | head -1)
             [ -n "$p" ] && lsof -a -p "$p" -d cwd -Fn | sed -n 's/^n//p'; }
reset() { pkill -f -- "--resume $SID" 2>/dev/null; sleep 0.2; echo 1 > "$T/panes"; }
lines() { echo "$1" | wc -l | tr -d ' '; }

# op-fork-keep: the fork runs in the session's directory (R7).
for case in "main:$main:$main" "worktree:$wt:$wt" "entered-later:$wt:$main"; do
  IFS=: read -r name d start <<< "$case"; reset
  PANE_START=$start; export PANE_START
  run "$d"
  if [ $rc -eq 0 ] && [[ $out == "op-fork-keep: forked into surface:"* ]] && [ "$(fork_cwd)" = "$d" ] \
     && [ "$(cat "$T/panes")" = 2 ] && [ "$(lines "$out")" = 1 ]; then ok "keep: forks in $name"
  else bad "keep: forks in $name: rc=$rc out=$out cwd=$(fork_cwd)"; fi
done
[ "$(git -C "$main" worktree list | wc -l | tr -d ' ')" = 2 ] && [ "$(git -C "$main" branch | wc -l | tr -d ' ')" = 2 ] \
  && ok "keep: no new worktree or branch" || bad "keep: a worktree or branch was made"

# op-fork-new-wt: a new worktree in the main checkout, named after the session (R23).
name=fork-ab12cd34
for case in "main:$main:$main:$name" "worktree:$wt:$wt:$name-2" "entered-later:$wt:$main:$name-3"; do
  IFS=: read -r cname d start wname <<< "$case"; reset
  PANE_START=$start; export PANE_START
  run "$d" --new-wt
  w="$main/.claude/worktrees/$wname"
  if [ $rc -eq 0 ] && [ "$out" = "op-fork-new-wt: forked into surface:91, in the new worktree $w from origin/main" ] \
     && [ "$(fork_cwd)" = "$w" ] && git -C "$main" show-ref -q --verify "refs/heads/worktree-$wname"; then ok "new-wt: forks in $cname into $wname"
  else bad "new-wt: forks in $cname: rc=$rc out=$out cwd=$(fork_cwd)"; fi
done

reset
out=$(cd "$main" && PATH="$T/bin:$PATH" CLAUDE_CODE_SESSION_ID="$SID" CMUX_SURFACE_ID= bash "$fork" 2>&1); rc=$?
[ $rc -ne 0 ] && [[ $out == *"not inside cmux"*"cd $main && claude --resume $SID --fork-session" ]] \
  && ok "keep, outside cmux: opens nothing, gives the command" || bad "keep, outside cmux: $out"
out=$(cd "$main" && PATH="$T/bin:$PATH" CLAUDE_CODE_SESSION_ID="$SID" CMUX_SURFACE_ID= bash "$fork" --new-wt 2>&1); rc=$?
[ $rc -ne 0 ] && [[ $out == "op-fork-new-wt: "*"not inside cmux"*"cd $main && claude --resume $SID --fork-session -w $name-4" ]] \
  && ok "new-wt, outside cmux: the command has -w and the next free name" || bad "new-wt, outside cmux: $out"

out=$(cd "$main" && PATH="$T/bin:$PATH" CLAUDE_CODE_SESSION_ID= CMUX_SURFACE_ID=surface:1 bash "$fork" 2>&1); rc=$?
[ $rc -ne 0 ] && [[ $out == *"no session ID"* ]] && ok "missing session ID" || bad "missing session ID: $out"

run "$T/nogit" --new-wt
[ $rc -ne 0 ] && [[ $out == *"is not in a git repo. Nothing opened." ]] && ok "new-wt outside git: opens nothing" || bad "new-wt outside git: $out"

reset; FAIL_SPLIT=1 run "$main"
[ $rc -ne 0 ] && [[ $out == "op-fork-keep: cmux new-split failed. Run by hand: "* ]] && [ "$(cat "$T/panes")" = 1 ] \
  && ok "new-split fails" || bad "new-split fails: $out"

reset; FAIL_CLAUDE=1 run "$main"
[ $rc -ne 0 ] && [[ $out == "op-fork-keep: claude did not start the fork. Run by hand: "* ]] && [ "$(cat "$T/panes")" = 1 ] \
  && [ "$(lines "$out")" = 1 ] && ok "claude fails: pane closed, nothing left" || bad "claude fails: $out panes=$(cat "$T/panes")"

reset; FAIL_CLAUDE=1 run "$main" --new-wt
[ $rc -ne 0 ] && [[ $out == "op-fork-new-wt: claude did not start the fork. Run by hand: "* ]] && [ "$(lines "$out")" = 1 ] \
  && [ ! -e "$main/.claude/worktrees/$name-4" ] && ok "new-wt, claude fails: no worktree left" || bad "new-wt, claude fails: $out"

# claude made the worktree, then the process never reaches forked: fail() removes both.
reset; FAIL_AFTER_WT=1 run "$main" --new-wt
[ $rc -ne 0 ] && [[ $out == "op-fork-new-wt: claude did not start the fork. Run by hand: "* ]] && [ "$(lines "$out")" = 1 ] \
  && [ ! -e "$main/.claude/worktrees/$name-4" ] && ! git -C "$main" show-ref -q --verify "refs/heads/worktree-$name-4" \
  && ok "new-wt, worktree made then claude fails: worktree and branch removed" || bad "new-wt, worktree left: $out"

reset; FAIL_SEND=1 run "$main"
[ $rc -ne 0 ] && [[ $out == "op-fork-keep: cmux send failed. Run by hand: "* ]] && [ "$(cat "$T/panes")" = 1 ] \
  && [ "$(lines "$out")" = 1 ] && ok "cmux send fails: pane closed, nothing left" || bad "cmux send fails: $out"

# Negative controls: the output check must fail on an unexpected branch, and on a
# missing new worktree.
chk="$(dirname "$fork")/check-output.sh"
wts=$(git -C "$main" worktree list --porcelain | grep '^worktree ')
"$chk" nothing nothing "$main" "$wts" "refs/heads/main" >/dev/null \
  && bad "output check passed with a new branch" || ok "output check fails on a new branch"
"$chk" forked forked "$main" "$wts" "$(git -C "$main" branch --format='%(refname)')" "$main/.claude/worktrees/none" refs/heads/worktree-none >/dev/null \
  && bad "output check passed with no new worktree" || ok "output check fails when the new worktree is missing"

echo "op-fork: $pass passed, $failn failed"
[ $failn -eq 0 ]
