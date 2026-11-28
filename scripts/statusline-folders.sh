#!/bin/bash
# The domain line of the status line: the domain of the session, or "no domain". Reads the status
# line JSON on stdin. Writes the added folders and the domain to the session files `dirs` and
# `domain`, for the other multi-folder parts. ~/.claude/statusline.sh calls it.
# Plan: plans/global/components/multi-folder/components/folder-status/.
map="$(dirname "${BASH_SOURCE[0]}")/project-map.py"
input=$(cat)
dirs=$(jq -r '.workspace.added_dirs // [] | .[]' <<< "$input" 2>/dev/null) || exit 0
domain=
# shellcheck disable=SC2086 # one path per line, no spaces in a mapped folder
[ -n "$dirs" ] && domain=$(IFS=$'\n'; python3 -I "$map" selected $dirs 2>/dev/null)
sid=$(jq -r '.session_id // empty' <<< "$input" 2>/dev/null)
if [ -n "$sid" ]; then
  st="${CLAUDE_MULTI_FOLDER_STATE:-$HOME/.claude/multi-folder}/${sid//[^A-Za-z0-9_-]/_}"
  if mkdir -p "$st" 2>/dev/null; then
    printf '%s' "${dirs:+$dirs$'\n'}" > "$st/dirs.tmp" && mv "$st/dirs.tmp" "$st/dirs"
    printf '%s' "$domain" > "$st/domain.tmp" && mv "$st/domain.tmp" "$st/domain"
  fi
fi
echo "${domain:-no domain}"
