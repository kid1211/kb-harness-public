#!/usr/bin/env bash
# Tests of the session-retro run: start.sh, retro.sh, commit-page.sh and reminder.sh.
# A stub `claude`, a throwaway `personal` repo with a bare origin, and written transcripts.
# Cases follow the runs of plans/session-retro/session-retro.qnt.
# Usage: test-session-retro.sh [name] [--skill <dir>]   name: run only tests whose name holds it.
#        --skill runs them on a broken copy of the skill, for a fixture run. V=1 prints each pass.
set -u
root="$(cd "$(dirname "$0")/../../.." && pwd)"
skill="$root/.claude/skills/session-retro"
only=""
while [ $# -gt 0 ]; do
  case $1 in --skill) skill=$2; shift 2 ;; *) only=$1; shift ;; esac
done
S="$skill/scripts"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0 failn=0
ok()  { pass=$((pass + 1)); [ -z "${V:-}" ] || echo "ok   $1"; }
bad() { failn=$((failn + 1)); echo "FAIL $1"; }
SID=abcdef12-3456-7890-abcd-ef1234567890

# A fresh KB with a bare origin, a state folder and a stub claude, for each test.
setup() {
  rm -rf "$T/case"; mkdir -p "$T/case/bin" "$T/case/state" "$T/case/nudge"
  C=$T/case
  git init -q --bare -b main "$C/origin.git"
  git init -q -b main "$C/kb"
  mkdir -p "$C/kb/.claude" "$C/kb/claude-research"
  ln -s "$root/.claude/CLAUDE.md" "$C/kb/.claude/CLAUDE.md"
  printf '.claude/\n' > "$C/kb/.gitignore"
  echo "a" > "$C/kb/notes.md"
  git -C "$C/kb" add -A && git -C "$C/kb" -c user.name=t -c user.email=t@t commit -q -m init
  git -C "$C/kb" remote add origin "$C/origin.git" && git -C "$C/kb" push -q -u origin main
  git -C "$C/kb" config user.name t && git -C "$C/kb" config user.email t@t
  cat > "$C/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$STUB_ARGS"; pwd -P > "$STUB_ARGS.cwd"; echo "start $$" >> "$STUB_ARGS.order"
[ "${STUB_FAIL:-}" ] && exit 1
[ "${STUB_SLEEP:-}" ] && sleep "$STUB_SLEEP"
uuid=$(sed -n 's/.*"uuid": *"\(u-blk\)".*/\1/p' "$STUB_TRANSCRIPT" | head -1)
reply=${STUB_REPLY:-"[{\"kind\": \"hook_block\", \"uuid\": \"$uuid\", \"subject\": \"x\", \"event\": \"The hook blocked a Write.\", \"cause\": \"A long sentence.\", \"change\": \"None.\", \"tip\": \"None.\", \"right\": \"yes\", \"avoidable\": \"yes\"}]"}
jq -n --arg r "$reply" '{result: $r, total_cost_usd: 0.1, usage: {cache_read_input_tokens: 1000}}'
echo "end $$" >> "$STUB_ARGS.order"
EOF
  chmod +x "$C/bin/claude"
  export SESSION_RETRO_STATE="$C/state" SESSION_RETRO_KB="$C/kb" SESSION_RETRO_CLAUDE="$C/bin/claude" \
         SESSION_RETRO_SETTLE=0 KB_NUDGE_DIR="$C/nudge" STUB_ARGS="$C/args" STUB_TRANSCRIPT="$C/t.jsonl"
  unset STUB_FAIL STUB_SLEEP STUB_REPLY
}

# A transcript whose last entry is $1 minutes old, with one hook block and a model line.
transcript() {
  python3 -I - "$1" "$C/t.jsonl" "${2:-claude-opus-5-5}" "${3:-1000}" <<'EOF'
import json, sys, datetime
age, path, model, tokens = int(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4])
now = datetime.datetime.now(datetime.timezone.utc)
ts = lambda m: (now - datetime.timedelta(minutes=m)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
lines = [
    {"type": "user", "uuid": "u-1", "timestamp": ts(age + 30), "message": {"content": "build it"}},
    {"type": "assistant", "uuid": "u-2", "timestamp": ts(age + 20), "message": {"model": model, "usage": {"input_tokens": 10, "cache_read_input_tokens": tokens}, "content": [{"type": "text", "text": "ok"}]}},
    {"type": "attachment", "uuid": "u-blk", "timestamp": ts(age + 10), "attachment": {"type": "hook_blocking_error", "hookName": "PostToolUse:Edit", "blockingError": {"blockingError": "too long", "command": ".claude/hooks/writing-check.py post"}}},
    {"type": "assistant", "uuid": "u-3", "timestamp": ts(age), "message": {"model": "<synthetic>", "content": [{"type": "text", "text": "API error"}]}},
]
open(path, "w").write("".join(json.dumps(l) + "\n" for l in lines))
EOF
}

retro() { bash "$S/retro.sh" "$SID" "$C/t.jsonl" "$C" >/dev/null 2>&1; }
page() { ls "$C/kb/claude-research/session-retro/"*-"${SID:0:8}".staging.md 2>/dev/null | head -1; }
t() { [[ $1 == *"$only"* ]]; }

# start.sh as a yes in worktree-end runs it: the session ID from the environment, the
# transcript found under the projects folder.
start() { # $1: the session ID, empty for none
  mkdir -p "$C/projects/-some-project"; cp "$C/t.jsonl" "$C/projects/-some-project/$SID.jsonl"
  (cd "$C" && CLAUDE_CODE_SESSION_ID=$1 SESSION_RETRO_PROJECTS="$C/projects" bash "${2:-$S}/start.sh")
}

# ask: start.sh prints STARTED and returns at once, while the run goes on.
if t start_fast; then setup; transcript 5
  mkdir -p "$T/slow"; cp "$S/start.sh" "$T/slow/"
  printf '#!/usr/bin/env bash\nsleep 5\n' > "$T/slow/retro.sh"
  t0=$(date +%s); out=$(start "$SID" "$T/slow"); rc=$?; took=$(( $(date +%s) - t0 ))
  [ $rc -eq 0 ] && [ "$out" = STARTED ] && [ $took -le 1 ] && ok "start_fast" || bad "start_fast: rc=$rc took=${took}s out=$out"
fi

# ask: a real run from start.sh writes the page.
if t start_runs; then setup; transcript 5
  start "$SID" >/dev/null
  for _ in $(seq 1 50); do [ -n "$(page)" ] && grep -qs done "$C/state/runs.log" && break; sleep 0.2; done
  [ -n "$(page)" ] && ok "start_runs" || bad "start_runs: no page; log: $(cat "$C/state/runs.log" "$C/state/failures.log" 2>/dev/null)"
fi

# noRunWithoutYes: with no session ID, or no transcript, start.sh says why and starts no run.
if t start_none; then setup; transcript 5
  out1=$(start "" ); rc1=$?
  out2=$(CLAUDE_CODE_SESSION_ID=nope SESSION_RETRO_PROJECTS="$C/projects" bash "$S/start.sh"); rc2=$?
  sleep 1
  [ $rc1 -ne 0 ] && [ "$out1" = NO_SESSION ] && [ $rc2 -ne 0 ] && [ "$out2" = NO_TRANSCRIPT ] && [ ! -f "$C/state/runs.log" ] \
    && ok "start_none" || bad "start_none: $rc1 $out1 / $rc2 $out2"
fi

# decide, coldNoRead: an old transcript gives a cold page, and claude is not called.
if t cold_page; then setup; transcript 90
  retro
  p=$(page)
  [ -n "$p" ] && grep -q "Not read: the last transcript entry is 9[0-9] minutes old." "$p" && [ ! -f "$C/args" ] \
    && ok "cold_page" || bad "cold_page: page=$p args=$(cat "$C/args" 2>/dev/null)"
fi

# decide: 60 minutes is fresh, 61 is cold.
if t age_edge; then setup; transcript 60
  retro; [ -f "$C/args" ] && r60=fork || r60=cold
  setup; transcript 61
  retro; [ -f "$C/args" ] && r61=fork || r61=cold
  [ "$r60 $r61" = "fork cold" ] && ok "age_edge" || bad "age_edge: 60=$r60 61=$r61"
fi

# runFails: a reply with no JSON list is a failure.
if t no_json; then setup; transcript 5; export STUB_REPLY="sorry, I cannot"
  retro
  grep -q "no list of findings" "$C/state/failures.log" 2>/dev/null && [ -z "$(page)" ] && ok "no_json" || bad "no_json: $(cat "$C/state/failures.log" 2>/dev/null)"
fi

# commit, failuresKept: a failed push leaves the page committed, and logged.
if t push_fails; then setup; transcript 5
  git -C "$C/kb" remote set-url origin "$C/gone.git"
  retro
  [ -n "$(git -C "$C/kb" log --format=%s | grep session-retro)" ] && grep -q "pull failed\|push failed" "$C/state/failures.log" 2>/dev/null \
    && ok "push_fails" || bad "push_fails: $(cat "$C/state/failures.log" 2>/dev/null)"
fi

# commit: a conflict in the pull is undone, so the KB is not left half rebased.
if t rebase_conflict; then setup; transcript 5
  git clone -q "$C/origin.git" "$C/other" && echo theirs > "$C/other/notes.md" && git -C "$C/other" add notes.md \
    && git -C "$C/other" -c user.name=t -c user.email=t@t commit -q -m theirs && git -C "$C/other" push -q
  echo mine > "$C/kb/notes.md" && git -C "$C/kb" commit -q -am mine
  retro
  [ ! -d "$C/kb/.git/rebase-merge" ] && [ ! -d "$C/kb/.git/rebase-apply" ] && grep -q "pull failed" "$C/state/failures.log" 2>/dev/null \
    && ok "rebase_conflict" || bad "rebase_conflict: $(ls "$C/kb/.git" | grep rebase) $(cat "$C/state/failures.log" 2>/dev/null)"
fi

# read, readOnlyWhenFresh: a fresh transcript forks the session, hook-free, on its model.
if t fork_args; then setup; transcript 5 claude-opus-5-5 250000
  retro
  a=$(cat "$C/args" 2>/dev/null)
  if grep -qx -- --fork-session <<<"$a" && grep -qx -- --no-session-persistence <<<"$a" && grep -qx "$SID" <<<"$a" \
     && grep -qx '{"disableAllHooks":true}' <<<"$a" && grep -qx 'claude-opus-5-5\[1m\]' <<<"$a" \
     && [ "$(cat "$C/args.cwd")" = "$(cd "$C" && pwd -P)" ] && grep -q "### F-" "$(page)"; then ok "fork_args"
  else bad "fork_args: $(tr '\n' ' ' <<<"$a" | cut -c1-300)"; fi
fi

# read: the <synthetic> line is skipped, and a small session keeps the plain model.
if t fork_model; then setup; transcript 5 claude-sonnet-5-5 1000
  retro
  grep -qx claude-sonnet-5-5 "$C/args" && ok "fork_model" || bad "fork_model: $(grep -A1 -- --model "$C/args")"
fi

# R15: the transcript is byte for byte the same after a run.
if t transcript_same; then setup; transcript 5
  before=$(shasum "$C/t.jsonl"); retro
  [ "$before" = "$(shasum "$C/t.jsonl")" ] && ok "transcript_same" || bad "transcript_same: the transcript changed"
fi

# commit: one commit of the page alone, pushed; a dirty file stays; the push works with the origin ahead.
if t commit_page_only; then setup; transcript 5
  git clone -q "$C/origin.git" "$C/other" && echo b > "$C/other/b.md" && git -C "$C/other" add b.md \
    && git -C "$C/other" -c user.name=t -c user.email=t@t commit -q -m ahead && git -C "$C/other" push -q
  echo dirty >> "$C/kb/notes.md"
  retro
  files=$(git -C "$C/kb" show --name-only --format= HEAD^{/session-retro} 2>/dev/null)
  if [ "$files" = "claude-research/session-retro/$(basename "$(page)")" ] && git -C "$C/kb" diff --quiet origin/main HEAD 2>/dev/null \
     && git -C "$C/kb" diff --name-only | grep -qx notes.md; then ok "commit_page_only"
  else bad "commit_page_only: files=$files log=$(cat "$C/state/failures.log" 2>/dev/null)"; fi
fi

# commit: personal on a branch other than main is refused.
if t not_main; then setup; transcript 5
  git -C "$C/kb" checkout -q -b side
  retro
  [ -z "$(git -C "$C/kb" log --format=%s | grep session-retro)" ] && grep -q "not main" "$C/state/failures.log" \
    && ok "not_main" || bad "not_main: committed, or no failure line"
fi

# runFails, failuresKept: a failed fork writes a line to the failure log.
if t fork_fails; then setup; transcript 5; export STUB_FAIL=1
  retro
  grep -q "the fork failed" "$C/state/failures.log" 2>/dev/null && [ -z "$(page)" ] && ok "fork_fails" || bad "fork_fails: $(cat "$C/state/failures.log" 2>/dev/null)"
fi

# runFails: a page with a secret is not in the KB, and the log says why.
if t secret_refused; then setup; transcript 5
  K=AKIA; export STUB_REPLY='[{"kind": "hook_block", "uuid": "u-blk", "subject": "x", "event": "It held '"${K}"'ABCDEFGHIJKLMNOP.", "cause": "c", "change": "None.", "tip": "None.", "right": "yes", "avoidable": "no"}]'
  retro
  [ -z "$(page)" ] && grep -q "secret pattern" "$C/state/failures.log" 2>/dev/null && ok "secret_refused" || bad "secret_refused: page=$(page)"
fi

# ask: a second run on the same session waits for the lock, then runs.
if t lock_wait; then setup; transcript 5; export STUB_SLEEP=2
  bash "$S/retro.sh" "$SID" "$C/t.jsonl" "$C" >/dev/null 2>&1 & first=$!
  sleep 0.5; unset STUB_SLEEP
  bash "$S/retro.sh" "$SID" "$C/t.jsonl" "$C" >/dev/null 2>&1; wait $first
  order=$(cut -d' ' -f1 "$C/args.order" | tr '\n' ' ')
  [ "$(grep -c "done" "$C/state/runs.log")" = 2 ] && [ "$order" = "start end start end " ] && ok "lock_wait" \
    || bad "lock_wait: order=$order log=$(cat "$C/state/runs.log")"
fi

# sessionStart: the reminder shows the failure log to the user, then empties it.
if t reminder_failures; then setup
  echo "2026-10-24 session abcdef12: the fork failed" > "$C/state/failures.log"; touch "$C/state/last-reminder"
  out=$(bash "$S/reminder.sh" </dev/null)
  [ "$(jq -r .systemMessage <<<"$out" | grep -c "the fork failed")" = 1 ] && [ "$(jq -r .hookSpecificOutput.additionalContext <<<"$out" | grep -c "the fork failed")" = 1 ] \
    && [ ! -s "$C/state/failures.log" ] && ok "reminder_failures" || bad "reminder_failures: $out"
fi

# sessionStart, dayPasses: the count shows with no last-reminder and at 7 days, not at 6.
if t reminder_weekly; then setup
  out1=$(bash "$S/reminder.sh" </dev/null)
  touch -t "$(date -v-6d +%Y%m%d%H%M)" "$C/state/last-reminder"; out6=$(bash "$S/reminder.sh" </dev/null)
  touch -t "$(date -v-7d -v-1M +%Y%m%d%H%M)" "$C/state/last-reminder"; out7=$(bash "$S/reminder.sh" </dev/null)
  if grep -q "open findings" <<<"$out1" && [ -z "$out6" ] && grep -q "open findings" <<<"$out7"; then ok "reminder_weekly"
  else bad "reminder_weekly: none=[$out1] 6d=[$out6] 7d=[$out7]"; fi
fi

# sessionStart: the reminder names a pattern in 2 sessions.
if t reminder_pattern; then setup; transcript 5
  retro; SID=99999999-aaaa-bbbb-cccc-dddddddddddd retro_two=1
  bash "$S/retro.sh" "$SID" "$C/t.jsonl" "$C" >/dev/null 2>&1; SID=abcdef12-3456-7890-abcd-ef1234567890
  out=$(bash "$S/reminder.sh" </dev/null)
  grep -q "pattern: hook_block: writing-check.py, in 2 sessions" <<<"$out" && ok "reminder_pattern" || bad "reminder_pattern: $out"
fi

echo "$pass passed, $failn failed"
[ $failn -eq 0 ] && [ $pass -gt 0 ]
