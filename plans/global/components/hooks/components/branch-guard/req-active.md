# Branch guard: detailed requirements

## Requirements

- ✅ **R19. Allow a worktree:** [implement] in a linked worktree of the harness, such as one under `.claude/worktrees/`, the commands that R23 refuses pass. Each `git worktree add` passes in each checkout, since it makes the branch together with its worktree. That covers `-b`, `-B`, and a name that only a remote has. *(the user, 2026-10-29)*
  - The commands of the `worktree-end` skill pass. The skill uses no `git switch`, so R13 does not touch them.
  - `.claude/CLAUDE.md` says that Claude makes a harness branch only with a worktree.
  - Serves: F2
- 🚀 **R7. How to set it up:** [research] answer the Research questions. The `!` part of Research question 1 waits for a live test in `p-build`. A good answer names a build that refuses each form of R23 and R13, and lets each form of R21, R17, R18 and R19 pass, with the repo that R24 finds. R7 holds when `p-research` answers each other Research question and marks Research question 1 deferred. *(the user, 2026-10-29)*
  - Serves: F3
- ✅ **R23. Block a new branch in the main checkout:** [implement] if a Bash command of Claude makes, renames or force-moves a git branch in the main checkout of the harness, the hook refuses it, with no prompt. Its message names `EnterWorktree`. *(the user, 2026-10-29)*
  - The main checkout is the primary working tree, on any branch: its git dir is the common git dir. R18 says which repo is the harness.
  - The commands: `git checkout <name>` when R17 refuses it. `git checkout` with `-b`, `-B`, `--orphan`, `--track` or `-t`. `git stash branch`. `git branch` with a name, with `-f`/`--force`, and `-m`/`-M`/`--move` or `-c`/`-C`/`--copy` with one or two names. Other forms, such as `git fetch <remote> a:b`, `git update-ref` and `gh pr checkout`, are a limit.
  - `git branch` with a list-mode flag passes: `--list`, `-l`, `--contains`, `--no-contains`, `--merged`, `--no-merged`, `--points-at`. The value or the pattern of such a flag, such as the `main` of `--merged main` or the `foo*` of `--list 'foo*'`, is not a name.
  - `git branch` with a delete or upstream flag passes: `-d`, `-D`, `--delete`, `-u`, `--set-upstream-to`, `--unset-upstream`, `--edit-description`.
  - `git branch` with no name passes, also with `-a`, `-r`, `-v`, `-vv`, `--sort`, `--format`, `--column` or `--show-current`. With a name, git makes a branch, as in `git branch -v x`, so the hook refuses it. *(the user, 2026-10-30)*
  - Serves: F1
- ✅ **R13. No `git switch`:** [implement] the hook refuses each git part that runs the `switch` subcommand, with each flag or none, in each repo and each checkout. Its message says to use `git checkout`. This holds in a worktree and in a KB too, so R13 wins over R18. *(the user, 2026-10-29)*
  - A quoted mention, such as `echo "git switch"`, passes. The argument of `bash -c` or `sh -c` is not a mention: R24 reads the git parts in it.
  - In the main checkout of the harness, the message for `git switch` with `-c`, `-C` or `--orphan` names only `EnterWorktree`, since R23 refuses `git checkout -b` there.
  - Serves: F1
- ✅ **R21. A Claude Code hook that fails open:** [implement] the guard is a `PreToolUse` hook on Bash in `.claude/settings.json`, not a git hook. It judges only the Bash calls of Claude. A command the user types in their terminal passes. Research question 1 finds out if a `!` command of the user reaches the hook. If it does, the hook judges it as a call of Claude, and that is a limit. *(the user, 2026-10-29)*
  - A git call inside a script that Claude runs, such as `bash x.sh`, also passes. That is a limit, not a goal.
  - A Bash call of a subagent counts as Claude's own, and the guard checks it.
  - The `settings.json` line finds the script from the git root, as R2 of the `hooks` plan asks. If that git root holds no script, the line runs the script of the session's project folder. So the hook also runs in a linked worktree of a KB, in another repo, and in a harness worktree made before the hook was on `main`. This fall back is an exception to R2 of the `hooks` plan. *(the user, 2026-10-29)*
  - If the hook cannot judge a call, such as in a folder outside a git repo, with bad JSON on stdin or after an error of the hook's own `git` call, the command passes and the hook prints a warning on stderr. A path the hook cannot read is not one of these cases: R24 judges the `cwd` for it.
  - Serves: F2
- ✅ **R24. Find the repo the command acts on:** [implement] the hook judges only the repo that git acts on. That covers `git -C <path>`, `cd <path> && git ...`, `git --git-dir=<path>` and `GIT_DIR=<path> git ...`. *(the user, 2026-10-29)*
  - The hook judges each git part of a compound command, such as `a && git checkout -b x`, and each git part inside `bash -c '...'` or `sh -c '...'`, one level deep. These are a limit: a git alias, such as `git co -b x`, a deeper `bash -c`, `eval`, `xargs`, a heredoc fed to a shell, such as `bash <<EOF`, a command substitution, such as `$(git checkout -b x)` or backticks, a git command name in a variable, such as `G=git; $G switch x`, and a function made with the word `function`, such as `function f { git switch x; }`. *(the user, 2026-10-30)*
  - If the hook cannot read the path, such as `git -C "$H"`, it judges the `cwd` of the hook input. That is a limit, not a goal.
  - Serves: F2
- ✅ **R17. A move to an existing branch:** [implement] in the main checkout of the harness, `git checkout <name>` with no flag of R23 is refused if a remote-tracking ref has `<name>` and no local branch has it, for one remote or more. The hook asks git for the refs, with no fetch. Else it passes, such as for a local branch, a tag, a commit, `origin/x`, a file path or `-`. *(the user, 2026-10-29)*
  - If the hook cannot read `<name>`, such as `git checkout "$(…)"`, the command passes, so `worktree-end` keeps working (R19).
  - Serves: F1
- ✅ **R18. Only the harness is judged:** [implement] R23 judges only the harness: each clone whose `.claude/skills` is a real folder and that holds `scripts/link-kb.sh`. A command that acts on another repo, such as the KB `personal`, passes R23, in its main checkout or in a linked worktree. The hook does not test if a repo is a KB. If a command sent from a KB acts on the harness, R23 judges it. *(the user, 2026-10-29)*
  - Serves: F2
