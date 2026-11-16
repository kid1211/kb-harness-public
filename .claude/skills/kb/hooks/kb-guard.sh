#!/usr/bin/env bash
# PreToolUse hook on Write, Edit, MultiEdit and Bash (knowledge-base-architecture).
# Bash: stamp a marker, so kb-after.sh finds the KB files the command changes.
# Write/Edit/MultiEdit: in a KB, kb-check.py guard prints deny or ask, or nothing to allow.
# A KB is a folder whose .claude/CLAUDE.md is a symlink into the harness.
in="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$in")"
if [[ "$tool" == Bash ]]; then
  sid="$(jq -r '.session_id // "none"' <<<"$in")"
  touch "${TMPDIR:-/tmp}/kb-bash-$sid"
  exit 0
fi
f="$(jq -r '.tool_input.file_path // empty' <<<"$in")"
[[ -n "$f" ]] || exit 0
d="$(dirname "$f")"
while [[ "$d" != / && "$d" != . ]]; do
  [[ -L "$d/.claude/CLAUDE.md" ]] && exec python3 -I "$(dirname "${BASH_SOURCE[0]}")/../scripts/kb-check.py" guard <<<"$in"
  d="$(dirname "$d")"
done
exit 0
