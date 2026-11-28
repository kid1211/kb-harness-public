# Code worktrees: designs not chosen

- **`EnterWorktree` in the code repo.** It makes worktrees only of the start folder, which is the harness.
- **Worktrees next to the repo, such as `<repo>-<name>/`.** The map look-up finds the project of a path by its folder, so a worktree outside the repo folder is on no row.
- **An entry in the repo's `.gitignore`.** That changes a tracked file of a repo others may share. `.git/info/exclude` is local.
