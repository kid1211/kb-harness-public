#!/bin/bash
# The status line: the folder (a red wt- in a worktree), the model, the context use and the domain.
# ~/.claude/statusline.sh is a link to this file, and settings.json of ~/.claude runs that link.
# Plan: plans/global/components/multi-folder/components/folder-status/.

# Read JSON input from stdin
input=$(cat)

# State file for tracking deltas between invocations
# Format: 4 lines — baseline_ctx_pct, baseline_total, last_ctx_pct, last_total
STATE_FILE="${STATUSLINE_STATE_FILE:-/tmp/.claude-statusline-state}"

# New prompt detection threshold (seconds)
# If state file is older than this, assume a new prompt started
PROMPT_GAP=3

# Extract context window information
usage=$(echo "$input" | jq '.context_window.current_usage')

# Initialize status parts
status_parts=()

# Add current directory (truncate if > 24 chars). Inside a linked worktree, show
# the main checkout's folder name prefixed with a red "wt-" instead.
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")
wt_prefix=""
read -r git_dir common_dir < <(git -C "$cwd" rev-parse --path-format=absolute --git-dir --git-common-dir 2>/dev/null | tr '\n' ' ')
if [ -n "$git_dir" ] && [ "$git_dir" != "$common_dir" ]; then
    dir_name=$(basename "$(dirname "$common_dir")")
    wt_prefix=$(printf '\033[38;5;196mwt-\033[0m')
fi
if [ ${#dir_name} -gt 24 ]; then
    dir_name="${dir_name:0:7}...${dir_name: -10}"
fi
# The domain of the session and its code folders, from the folders it added with --add-dir or
# /add-dir (harness scripts/statusline-folders.sh, plan plans/global/components/multi-folder/)
status_parts+=("${wt_prefix}${dir_name}")
folders_script="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/statusline-folders.sh"
if [ -x "$folders_script" ]; then
    folders=$(echo "$input" | "$folders_script" 2>/dev/null)
    domain=$(sed -n 1p <<< "$folders")       # line 1: the domain, the last part of the line
    code_folders=$(sed -n 2p <<< "$folders") # line 2: the code folders, printed under the line
fi

# Add model display name
model=$(echo "$input" | jq -r '.model.display_name')
status_parts+=("$model")

# Add reminder count if .claude/REMINDERS.md exists and has content
reminders_file="$cwd/.claude/REMINDERS.md"
if [ -f "$reminders_file" ]; then
    reminder_count=$(grep -c -v '^[[:space:]]*$' "$reminders_file" 2>/dev/null || echo 0)
    if [ "$reminder_count" -gt 0 ]; then
        # Yellow warning color
        reminder_display=$(printf '\033[38;5;220m⚠ %d reminder%s\033[0m' "$reminder_count" "$([ "$reminder_count" -gt 1 ] && echo 's')")
        status_parts+=("$reminder_display")
    fi
fi

# Detect whether this is a new user prompt or a continuation
# (AskUserQuestion click, tool result, etc.)
is_new_prompt() {
    # No state file = first ever call
    [ ! -f "$STATE_FILE" ] && return 1

    # Check time gap since last invocation
    local now last_mod gap
    now=$(date +%s)
    if [[ "$OSTYPE" == darwin* ]]; then
        last_mod=$(stat -f %m "$STATE_FILE")
    else
        last_mod=$(stat -c %Y "$STATE_FILE")
    fi
    gap=$((now - last_mod))

    # Within PROMPT_GAP seconds = same prompt (mid-execution)
    [ "$gap" -lt "$PROMPT_GAP" ] && return 1

    # Time gap detected — check transcript to distinguish
    # new user prompt (string) vs AskUserQuestion/tool response (array)
    local transcript_path last_user_content_type
    transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
    if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
        # Read transcript backwards to find last user message efficiently
        if [[ "$OSTYPE" == darwin* ]]; then
            last_user_content_type=$(tail -r "$transcript_path" \
                | jq -r 'select(.type == "user") | (.message.content | type)' 2>/dev/null \
                | head -1)
        else
            last_user_content_type=$(tac "$transcript_path" \
                | jq -r 'select(.type == "user") | (.message.content | type)' 2>/dev/null \
                | head -1)
        fi

        # string = user typed a new prompt → new prompt
        # array  = tool_result (AskUserQuestion click, etc.) → continuation
        [ "$last_user_content_type" = "string" ] && return 0
        return 1
    fi

    # No transcript available — fall back to time gap only
    return 0
}

# Read previous state and detect new prompt
baseline_ctx_pct=""
baseline_total=""
if [ -f "$STATE_FILE" ]; then
    if is_new_prompt; then
        # New prompt — baseline becomes the last invocation's values
        baseline_ctx_pct=$(sed -n '3p' "$STATE_FILE")
        baseline_total=$(sed -n '4p' "$STATE_FILE")
    else
        # Same prompt — keep existing baselines
        baseline_ctx_pct=$(sed -n '1p' "$STATE_FILE")
        baseline_total=$(sed -n '2p' "$STATE_FILE")
    fi
fi

# Human-readable number formatting (1.2k, 45.3k, 1.2M)
format_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        # Show one decimal for millions
        printf '%s.%sM' "$((n / 1000000))" "$((n % 1000000 / 100000))"
    elif [ "$n" -ge 1000 ]; then
        local whole=$((n / 1000))
        local frac=$((n % 1000 / 100))
        if [ "$frac" -gt 0 ]; then
            printf '%s.%sk' "$whole" "$frac"
        else
            printf '%sk' "$whole"
        fi
    else
        printf '%s' "$n"
    fi
}

# Context window usage (Orange) - shows % used with delta from prompt start
ctx_pct=""
if [ "$usage" != "null" ]; then
    current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    size=$(echo "$input" | jq '.context_window.context_window_size')

    if [ "$current" != "null" ] && [ "$size" != "null" ] && [ "$size" -gt 0 ]; then
        ctx_pct=$((current * 100 / size))

        # Build delta string (from prompt baseline)
        ctx_delta=""
        if [ -n "$baseline_ctx_pct" ]; then
            diff=$((ctx_pct - baseline_ctx_pct))
            if [ "$diff" -ge 0 ]; then
                ctx_delta=" (+${diff}%)"
            else
                ctx_delta=" (${diff}%)"
            fi
        fi

        # Orange color
        ctx_display=$(printf '\033[38;5;208mCTX: %d%%%s\033[0m' "$ctx_pct" "$ctx_delta")
        status_parts+=("$ctx_display")
    fi
fi

# Token usage (Green) - shows cumulative total with delta from prompt start
total_input=$(echo "$input" | jq '.context_window.total_input_tokens')
total_output=$(echo "$input" | jq '.context_window.total_output_tokens')
current_total=""

if [ "$total_input" != "null" ] && [ "$total_output" != "null" ]; then
    current_total=$((total_input + total_output))

    if [ "$current_total" -gt 0 ]; then
        total_fmt=$(format_tokens "$current_total")

        # Build delta string (from prompt baseline)
        tkn_delta=""
        if [ -n "$baseline_total" ]; then
            diff=$((current_total - baseline_total))
            if [ "$diff" -gt 0 ]; then
                diff_fmt=$(format_tokens "$diff")
                tkn_delta=" (+${diff_fmt})"
            fi
        fi

        # Green color
        tkn_display=$(printf '\033[38;5;34mTKN: %s%s\033[0m' "$total_fmt" "$tkn_delta")
        # status_parts+=("$tkn_display")  # TKN hidden 2026-11-20; the count still feeds the state file
    fi
fi

# Write state: baselines (lines 1-2) + current values (lines 3-4)
# If baselines are empty (first call of prompt), use current values so
# subsequent calls within the same prompt can show deltas from this point
{
    echo "${baseline_ctx_pct:-$ctx_pct}"
    echo "${baseline_total:-$current_total}"
    echo "${ctx_pct}"
    echo "${current_total}"
} > "$STATE_FILE"

# The domain last, in palette light-blue #A8D8EA
if [ -n "$domain" ]; then status_parts+=("$(printf '\033[38;2;168;216;234m%s\033[0m' "$domain")"); fi

# Join all parts with separator
printf '%s' "${status_parts[0]}"
for ((i=1; i<${#status_parts[@]}; i++)); do
    printf ' | %s' "${status_parts[i]}"
done
if [ -n "$code_folders" ]; then printf '\n%s' "$code_folders"; fi   # an if, so the script exits 0: a non-zero exit hides the status line
