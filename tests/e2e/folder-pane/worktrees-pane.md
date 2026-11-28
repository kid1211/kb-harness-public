# folder-pane: the worktrees button opens the Worktrees pane, and a made worktree opens in VS Code

## Covers

- `.claude/skills/folder-pane/hooks/worktrees.tsx`
- `.claude/skills/writing-mode/hooks/register.tsx`

## Setup

1. Make a temp folder `$T`, outside any git repo.
2. Run `git clone <checkout> $T/h`, with `<checkout>` the harness checkout you test.
3. Make the git repo `$T/r` with one commit, then run `git -C $T/r worktree add -q $T/r/.claude/worktrees/w -b w`.
4. Make the folder `$T/plain`, outside git.

## Steps

1. In `$T/h`, run `claude plugin test .claude/skills/folder-pane` and `claude plugin test .claude/skills/writing-mode`.
2. In `$T/r`, start `claude --plugin-dir $T/h/.claude/skills/folder-pane --plugin-dir $T/h/.claude/skills/writing-mode --add-dir $T/plain`.
3. Look at the button line above the prompt.
4. Press `worktrees`.
5. In the pane, press the line of `$T/r/.claude/worktrees/w`.
6. Press the line of the main checkout `$T/r`.
7. Press `worktrees` again. Then type `/worktrees`.

## Expected

1. Step 1 prints `0 fail` for each mod: a pass count of at least 19 for folder-pane, and at least 15 for writing-mode.
2. In step 3, the buttons are in this order: `⧉ domain`, `worktrees`, `⚙ config`.
3. In step 4, a pane titled `Worktrees` opens. It shows `$T/r` once, with its branch, then `$T/r/.claude/worktrees/w` with the branch `w`. It marks `$T/r` as the folder this session runs in. It says that `$T/plain` is not in git.
4. In step 5, VS Code opens the folder `$T/r/.claude/worktrees/w`, and its Source Control view shows that worktree.
5. In step 6, nothing opens: the main checkout is no button.
6. In step 7, the press closes the pane, and `/worktrees` opens it again.

## Cleanup

1. Quit the session, and close the VS Code window of step 5.
2. Delete `$T`.
