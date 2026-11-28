#!/usr/bin/env bash
# PostToolUse hook on Write, Edit, MultiEdit and Bash (knowledge-base-architecture).
# Write/Edit/MultiEdit in a KB: kb-check.py after checks the file, and for staging
# shows the confirmed headings of the topic so Claude compares them.
# Bash: if a KB file is newer than the marker kb-guard.sh stamped, kb-check.py after
# names it, so Claude tells the user.
in="$(cat)"
py="$(dirname "${BASH_SOURCE[0]}")/../scripts/kb-check.py"
tool="$(jq -r '.tool_name // empty' <<<"$in")"
if [[ "$tool" == Bash ]]; then
  sid="$(jq -r '.session_id // "none"' <<<"$in")"
  marker="${TMPDIR:-/tmp}/kb-bash-$sid"
  [[ -e "$marker" ]] || exit 0
  for kb in "${KB_HOME:-$HOME/second-brain}"/*/; do
    [[ -L "$kb.claude/CLAUDE.md" ]] || continue
    if [[ -n "$(find "$kb" -path '*/.*' -prune -o -newer "$marker" -print -quit)" ]]; then
      KB_BASH_MARKER="$marker" exec python3 -I "$py" after <<<"$in"
    fi
  done
  exit 0
fi
f="$(jq -r '.tool_input.file_path // empty' <<<"$in")"
[[ -n "$f" ]] || exit 0
d="$(dirname "$f")"
while [[ "$d" != / && "$d" != . ]]; do
  [[ -L "$d/.claude/CLAUDE.md" ]] && exec python3 -I "$py" after <<<"$in"
  d="$(dirname "$d")"
done
exit 0
