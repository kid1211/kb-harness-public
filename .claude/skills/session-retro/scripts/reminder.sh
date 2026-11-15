#!/usr/bin/env bash
# SessionStart hook, matcher startup: show the failure log, and once in 7 days the open
# findings and their patterns. The user sees systemMessage. Claude sees additionalContext.
here=$(cd "$(dirname "$0")" && pwd)
state=${SESSION_RETRO_STATE:-$HOME/.claude/session-retro}
mkdir -p "$state" 2>/dev/null || exit 0
out=""
# Rename the log before reading it, so a line a run adds now goes to a new log.
if [[ -s $state/failures.log ]] && mv "$state/failures.log" "$state/failures.log.$$"; then
  out+=$'Session retro failures:\n'"$(cat "$state/failures.log.$$")"$'\n'
  rm -f "$state/failures.log.$$"
fi
last=$state/last-reminder
if [[ ! -f $last ]] || (( $(date +%s) - $(date -r "$last" +%s) >= 7 * 86400 )); then
  if summary=$(python3 -I "$here/findings-page.py" summary 2>&1); then
    out+="Session retro: $summary"$'\n'
    out+="Review the pages in claude-research/session-retro/ of the KB. Set each finding to confirmed or dropped. Run /session-retro for the list."
    touch "$last"
  fi
fi
[[ -z $out ]] && exit 0
jq -n --arg m "$out" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ("Tell the user: " + $m)}}'
