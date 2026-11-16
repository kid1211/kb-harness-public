#!/usr/bin/env bash
# The kb hooks end to end, on a throwaway KB: what kb-guard.sh decides for each area,
# and what kb-after.sh tells Claude after a write and after a Bash command.
# kb-check.py --test covers each rule. This suite covers the shell around it.
set -u
H="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.claude/skills/kb/hooks" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp" KB_HOME="$T/home"; mkdir -p "$TMPDIR" "$KB_HOME/kb/.claude" "$KB_HOME/kb/member" "$T/harness"
touch "$T/harness/CLAUDE.md"; ln -s "$T/harness/CLAUDE.md" "$KB_HOME/kb/.claude/CLAUDE.md"
K="$KB_HOME/kb"
printf -- '---\nconfidence: 3\nconfirmed: 2026-10-23\n---\n# Member\n' > "$K/member/status.md"
pass=0 fail=0
t() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); [[ -n "${V:-}" ]] && echo "ok   $1"; else fail=$((fail+1)); echo "FAIL $1: got '$2', want '$3'"; fi; }
guard() { jq -nc --arg t "$1" --arg f "$2" --arg c "${3:-}" '{session_id:"s",tool_name:$t,tool_input:{file_path:$f,content:$c,command:"x"}}' | bash "$H/kb-guard.sh" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
after() { jq -nc --arg t "$1" --arg f "${2:-}" '{session_id:"s",tool_name:$t,tool_input:{file_path:$f,command:"x"}}' | bash "$H/kb-after.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

t "outside a KB: allowed" "$(guard Write "$T/harness/x.md")" ""
t "no area: denied" "$(guard Write "$K/member/IMG_1.jpeg")" deny
t "undated source: denied" "$(guard Write "$K/member/scan.source.pdf")" deny
t "dated source: allowed" "$(guard Write "$K/member/2026-10-01-scan.source.pdf")" ""
t "staging: allowed" "$(guard Write "$K/member/x.staging.md" anything)" ""
t "consolidated, no score: denied" "$(guard Write "$K/member/new.md" '# New')" deny
t "consolidated, complete: ask" "$(guard Write "$K/member/status.md" "$(cat "$K/member/status.md")")" ask
t "CLAUDE.md: allowed" "$(guard Write "$K/member/CLAUDE.md" x)" ""

guard Bash "" >/dev/null
t "Bash before stamps a marker" "$([[ -e "$TMPDIR/kb-bash-s" ]] && echo yes)" yes
sleep 1
t "Bash that changes nothing: no message" "$(after Bash)" ""
guard Bash "" >/dev/null; sleep 1; echo "# changed" > "$K/member/status.md"
t "Bash that changes a page: flagged" "$(after Bash | grep -c 'changed outside the guard')" 1
printf 'x\n' > "$K/member/note.staging.md"
t "staging write: compare context" "$(after Write "$K/member/note.staging.md" | grep -c 'status.md')" 1
t "write outside a KB: no message" "$(after Write "$T/harness/CLAUDE.md")" ""

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
