#!/bin/bash
# DirectoryAdded and UserPromptSubmit. /add-dir saves the folder to the session file
# (Claude Code drops the output of DirectoryAdded). The next prompt tells Claude the
# project, role and supporting docs of each saved folder it was not told yet, once.
# The status line saves the folders of --add-dir too. It always exits 0.
# Plan: plans/global/components/multi-folder/components/add-dir-context/.
input=$(cat)
# \x1f, not a tab: read keeps an empty field only with a separator that is not white space.
IFS=$'\x1f' read -r event sid dir < <(jq -r '[.hook_event_name // "", .session_id // "", .directory // ""] | join("\u001f")' <<< "$input" 2>/dev/null) || exit 0
[ -n "$sid" ] || exit 0
st="${CLAUDE_MULTI_FOLDER_STATE:-$HOME/.claude/multi-folder}/${sid//[^A-Za-z0-9_-]/_}"
mkdir -p "$st" 2>/dev/null && touch "$st/dirs" "$st/told" 2>/dev/null || exit 0

if [ "$event" = DirectoryAdded ]; then
  [ -n "$dir" ] && ! grep -Fxq "$dir" "$st/dirs" && echo "$dir" >> "$st/dirs"
  exit 0
fi
[ "$event" = UserPromptSubmit ] || exit 0
new=()
while IFS= read -r d; do
  [ -n "$d" ] && ! grep -Fxq "$d" "$st/told" && new+=("$d")
done < "$st/dirs"
[ ${#new[@]} -eq 0 ] && exit 0
lines=$(python3 -I "$(dirname "$0")/../../scripts/folder-context.py" "${new[@]}" 2>/dev/null) || exit 0
jq -n --arg c "Folders added to this session, from the project map:"$'\n'"$lines" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}' \
  && printf '%s\n' "${new[@]}" >> "$st/told"
exit 0
