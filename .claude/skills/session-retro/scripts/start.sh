#!/usr/bin/env bash
# start.sh: start the retro of this session in the background, and return at once.
# Run from the main checkout. The session ID comes from Claude Code's environment.
sid=${CLAUDE_CODE_SESSION_ID:-}
[[ -n $sid ]] || { echo NO_SESSION; exit 1; }
transcript=$(ls "${SESSION_RETRO_PROJECTS:-$HOME/.claude/projects}"/*/"$sid.jsonl" 2>/dev/null | head -1)
[[ -f $transcript ]] || { echo NO_TRANSCRIPT; exit 1; }
nohup bash "$(dirname "$0")/retro.sh" "$sid" "$transcript" "$PWD" </dev/null >/dev/null 2>&1 &
echo STARTED
