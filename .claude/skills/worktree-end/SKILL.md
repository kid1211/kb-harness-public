---
name: worktree-end
description: Close a worktree that EnterWorktree opened - merge it through a pushed branch and a PR, leave it for now, or discard it - then call ExitWorktree. Never removes unmerged commits without a typed `delete`.
when_to_use: The user says "worktree-end", "close this worktree", "wrap up this worktree", "merge and clean up this worktree" or "exit worktree". "Exit worktree" starts this skill at Step 0. It is not a direct ExitWorktree call. Skip if the session is not in an EnterWorktree worktree.
user-invocable: true
---

# Worktree end

Plan: `plans/worktree-end/`. `S` is `bash <this skill's base directory>/scripts/wt-end.sh`, by absolute path. Each `S` command prints one line. Act on its first word. Do not repeat the line to the user unless a step says so.

- Every invocation starts at Step 0, also a repeat and "exit worktree".
- A rejected or cancelled question is not an answer. Ask again. Never fall through to a default.
- Only the literal word `delete` confirms a discard or a forced removal. "yes" is a decline.
- After every ExitWorktree call, run Step 5.

## Step 0: State

Run `S status`.

- `DIRTY` → show the user the files. Go to Step 1, and say Merge now commits them.
- Anything else → keep the line for the next steps.

## Step 1: Ask

AskUserQuestion, options in this order:

1. **Merge** (recommended) → Step 2.
2. **Switch away for now** → ask "Leave without merging? A new session may be better." Options: "No, merge instead" (recommended) → Step 2. "Yes, exit unmerged" → `ExitWorktree(keep)`.
3. **Merge now**: commit any changes, push, open the PR and merge it unread. For small work → Step 3.
4. **Discard and remove** → Step 4.

If the status is `DIRTY` and the answer is not Merge now: ask the user to commit or discard the files. Stop.

## Step 2: Merge

By the status word:

- `EMPTY` → say there are no commits beyond the default branch. `ExitWorktree(remove, discard_changes: true)`.
- `UNPUSHED`, `DRIFT`, `PR_NONE` → `S push`. Give the user the URL. `ExitWorktree(keep)`. Do not wait or poll.
- `PR_OPEN` → say the PR is still open, with its URL. `ExitWorktree(keep)`.
- `PR_MERGED` → `ExitWorktree(remove, discard_changes: true)`.
- `PR_CLOSED` → say the PR was closed unmerged. Ask the user what to do. No ExitWorktree.

## Step 3: Merge now

If the status is `DIRTY`: stage the listed files by path, never `git add -A`. Commit them with a message that says what changed. Run `S status` again.

If the status is `EMPTY`, do as Step 2. Otherwise run `S merge`.

- `MERGED` → `ExitWorktree(remove, discard_changes: true)`.
- `BLOCKED` or `FAILED` → **stay in the worktree. No ExitWorktree.** Tell the user why, with the PR URL:
  - `CONFLICTING` or `DIRTY`: a merge conflict. `BEHIND`: the default branch moved. `BLOCKED` or `UNSTABLE`: a check or a review.
  - Offer to rebase onto `origin/<default>`, fix it, commit, and run this skill again.

## Step 4: Discard

- `EMPTY` → `ExitWorktree(remove, discard_changes: true)`.
- Otherwise ask in plain text, not AskUserQuestion: "This deletes `<branch>` and its commits. They are not merged. Type `delete` to confirm." On `delete`: `ExitWorktree(remove, discard_changes: true)`. On anything else: say the worktree is unchanged, and go back to Step 1.

## Step 5: After ExitWorktree

1. If `remove` failed because this session does not own the worktree:
   1. `ExitWorktree(keep)`.
   2. Ask in plain text: "ExitWorktree will not remove this worktree: this session does not own it. Type `delete` to remove it with git, or anything else to keep it."
   3. On `delete`: `S force-remove <worktree-path> <branch>`. If it prints `FAILED`, show the user the line.
   4. On anything else: say the worktree stays on disk and needs manual removal.
2. Land the primary checkout on the default branch:

   ```sh
   [ -z "$(git status --porcelain)" ] && git checkout -q "$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d/ -f2-)" && echo LANDED || echo NOT_LANDED
   ```

   If it prints `NOT_LANDED`, tell the user the primary checkout has its own changes, and leave it.
3. AskUserQuestion: "Run a session retro?" Options: "Yes", "No".
   - Yes → `bash "$(git rev-parse --show-toplevel)/.claude/skills/session-retro/scripts/start.sh"`. If it prints `STARTED`, say the page lands in `claude-research/session-retro/` of `personal` in a few minutes. If the script is missing, say `session-retro` is not merged yet. Otherwise show the line.
   - No → nothing.
