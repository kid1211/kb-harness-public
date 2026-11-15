#!/usr/bin/env bash
# retro.sh <session_id> <transcript> <cwd>: the retro of one session, in the background.
# A fresh transcript is judged by a fork of the session; an old one gets a one-line page.
# The page is committed alone in the KB. Each failure goes to failures.log.
set -u
here=$(cd "$(dirname "$0")" && pwd)
export SESSION_RETRO_STATE=${SESSION_RETRO_STATE:-$HOME/.claude/session-retro}
state=$SESSION_RETRO_STATE
claude_bin=${SESSION_RETRO_CLAUDE:-claude}
settle=${SESSION_RETRO_SETTLE:-3}
sid=$1 transcript=$2 cwd=${3:-$HOME}
mkdir -p "$state"
log() { echo "$(date '+%F %T') ${sid:0:8} $*" >> "$state/runs.log"; }
fail() { echo "$(date '+%F %T') session ${sid:0:8}: $*" >> "$state/failures.log"; log "failed: $*"; exit 1; }

# One run per session at a time. A second run waits up to 10 minutes, then fails.
# A lock is stale when its PID is gone, or when it has no PID a minute after it was made.
# A stale lock is renamed before removal, so two waiters never remove a new lock.
lock="$state/lock-$sid" got=""
for _ in $(seq 1 600); do
  if mkdir "$lock" 2>/dev/null; then got=1; break; fi
  pid=$(cat "$lock/pid" 2>/dev/null)
  if { [[ -n $pid ]] && ! kill -0 "$pid" 2>/dev/null; } || { [[ -z $pid ]] && (( $(date +%s) - $(date -r "$lock" +%s 2>/dev/null || date +%s) > 60 )); }; then
    mv "$lock" "$lock.stale.$$" 2>/dev/null && rm -rf "$lock.stale.$$"
    continue
  fi
  sleep 1
done
[[ -n $got ]] || fail "the lock of the session stayed busy for 10 minutes"
echo $$ > "$lock/pid"
trap 'rm -rf "$lock" "$state/reply-$sid.txt" "$state/findings-$sid.json"' EXIT

# The transcript is written in the background: wait until it stops growing, 20 checks at most.
size=-1
for _ in $(seq 1 20); do
  now=$(wc -c < "$transcript" 2>/dev/null) || fail "no transcript at $transcript"
  [[ $now == "$size" ]] && break
  size=$now; sleep "$settle"
done

# The date of the first entry, the age in minutes of the last, and the session's model.
read -r first age model < <(python3 -I - "$transcript" <<'EOF'
import json, sys, datetime
first = last = model = None
tokens = 0
for line in open(sys.argv[1], errors="replace"):
    try:
        o = json.loads(line)
    except ValueError:
        continue
    ts = o.get("timestamp")
    if ts:
        first = first or ts
        last = ts
    m = (o.get("message") or {}) if o.get("type") == "assistant" else {}
    if m.get("model") and m["model"] != "<synthetic>":
        model = m["model"]
        u = m.get("usage") or {}
        tokens = sum(u.get(k) or 0 for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
if not last:
    sys.exit(1)
age = (datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(last.replace("Z", "+00:00"))).total_seconds() // 60
model = (model or "") + ("[1m]" if model and tokens > 200000 and not model.endswith("]") else "")
print(first[:10], int(age), model or "-")
EOF
)
[[ -n ${age:-} ]] || fail "the transcript has no timestamp"

if (( age > 60 )); then
  page=$(python3 -I "$here/findings-page.py" cold "$sid" "$first" "$age") || fail "the cold page failed"
  if [[ $page == kept ]]; then log "cold, the full page is kept"; exit 0; fi
else
  prompt=$(python3 -I "$here/findings.py" prompt "$transcript") || fail "the scan failed"
  # --resume finds the session by the folder it ran in.
  cd "$cwd" 2>/dev/null || cd "$HOME" || fail "no folder to fork from"
  args=(--resume "$sid" --fork-session -p "$prompt" --max-turns 1 --no-session-persistence
        --permission-mode dontAsk --settings '{"disableAllHooks":true}' --output-format json)
  [[ $model != - ]] && args+=(--model "$model")
  # A fork can end with no list, such as when it tries a tool. Then it runs once more.
  listed=""
  for try in 1 2; do
    out=$("$claude_bin" "${args[@]}" 2>>"$state/runs.log") || fail "the fork failed"
    cache=$(jq -r '.usage.cache_read_input_tokens // 0' <<<"$out" 2>/dev/null)
    log "fork $try: $(jq -r '.subtype // "?"' <<<"$out" 2>/dev/null), cost \$$(jq -r '.total_cost_usd // "?"' <<<"$out" 2>/dev/null), cache read ${cache:-0} tokens"
    [[ ${cache:-0} == 0 ]] && log "the fork read no cache"
    jq -r '.result // ""' <<<"$out" > "$state/reply-$sid.txt" 2>/dev/null || fail "the fork gave no JSON"
    if python3 -I "$here/findings.py" check "$transcript" "$state/reply-$sid.txt" > "$state/findings-$sid.json" 2>>"$state/runs.log"; then
      listed=1; break
    fi
  done
  [[ -n $listed ]] || fail "the fork's reply holds no list of findings"
  page=$(python3 -I "$here/findings-page.py" full "$sid" "$first" "$state/findings-$sid.json") || fail "the page failed"
fi

dest=$(python3 -I "$here/findings-page.py" move "$page" 2>&1) || fail "${dest:-the move into the KB failed}"
why=$(bash "$here/commit-page.sh" "$dest" 2>&1) || fail "commit: $why"
log "done: $dest"
