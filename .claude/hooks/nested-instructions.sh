#!/bin/bash
# PostToolUse on Read, Edit and Write, and InstructionsLoaded. If the file is outside the
# start folder, give Claude each CLAUDE.md between the file and the top of its repo, once
# per session, and the top's own one when the repo was not added. Claude Code loads these
# on its own only in the start folder. A CLAUDE.md that Claude Code loaded (InstructionsLoaded)
# is noted and never given. It always exits 0, so it never blocks a call.
# Plan: plans/global/components/multi-folder/components/nested-instructions/.
input=$(cat)
# \x1f, not a tab: read keeps an empty field only with a separator that is not white space.
IFS=$'\x1f' read -r event file cwd sid reason < <(jq -r '[.hook_event_name // "", .tool_input.file_path // .file_path // "", .cwd // "", .session_id // "", .load_reason // ""] | join("\u001f")' <<< "$input" 2>/dev/null) || exit 0
[ -n "$file" ] && [ -n "$sid" ] || exit 0
st="${CLAUDE_MULTI_FOLDER_STATE:-$HOME/.claude/multi-folder}/${sid//[^A-Za-z0-9_-]/_}"
mkdir -p "$st" 2>/dev/null && touch "$st/instructions" 2>/dev/null || exit 0
if [ "$event" = InstructionsLoaded ]; then
  printf '%s\t%s\n' "$file" "${reason:-loaded}" >> "$st/instructions"
  exit 0
fi
[ -n "$cwd" ] || exit 0
# In the start folder by its own path, or by the resolved one below.
case "$(dirname "$file")/" in "${cwd%/}"/*) exit 0 ;; esac
dir=$(cd "$(dirname "$file")" 2>/dev/null && pwd -P) || exit 0
cwd=$(cd "$cwd" 2>/dev/null && pwd -P) || exit 0
case "$dir/" in "$cwd"/*) exit 0 ;; esac
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && repo=1 || { top=$(cd "$HOME" && pwd -P); repo=; }
case "$dir/" in "$top"/*) ;; *) exit 0 ;; esac

had() { cut -f1 "$st/instructions" | grep -Fxq "$1"; }
# A folder above the start folder: Claude Code loads its CLAUDE.md already.
above_start() { case "$cwd/" in "$1"/*) return 0 ;; esac; return 1; }
found=()
d=$dir
while [ "$d" != "$top" ] && [ "$d" != / ]; do
  above_start "$d" || { [ -f "$d/CLAUDE.md" ] && ! had "$d/CLAUDE.md" && found=("$d/CLAUDE.md" "${found[@]}"); }
  d=$(dirname "$d")
done
# The top of a repo that is not added and not the start folder: nothing loaded its CLAUDE.md.
if [ -n "$repo" ] && [ -f "$top/CLAUDE.md" ] && ! above_start "$top" && ! grep -Fxq "$top" "$st/dirs" 2>/dev/null \
  && ! had "$top/CLAUDE.md"; then
  found=("$top/CLAUDE.md" "${found[@]}")
fi
[ ${#found[@]} -eq 0 ] && exit 0

ctx=""
for f in "${found[@]}"; do
  ctx+="Instructions from $f:"$'\n'"$(cat "$f")"$'\n\n'
done
# Mark the files given only once the output is out.
jq -n --arg c "$ctx" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}' \
  && printf '%s\thook\n' "${found[@]}" >> "$st/instructions"
exit 0
