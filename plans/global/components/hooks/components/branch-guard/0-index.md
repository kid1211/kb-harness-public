# Branch guard

## Goal

A Claude Code hook stops Claude from making a git branch in the main checkout of the harness. A KB passes, since the hook judges only the harness for that rule (R18). Apart from the limits that R23, R21, R24 and R17 name, a worktree is then the only way Claude makes a harness branch. Claude uses `git checkout`, never `git switch`. Draft, 8 requirements, 0 components.

Builds: `.claude/hooks/branch-guard.sh`, `.claude/settings.json` (the `PreToolUse` line of branch-guard), `tests/global/hooks/test-branch-guard.sh`, `.claude/CLAUDE.md` (the line "Claude makes a harness branch only with a worktree"), the line of the suite in the Tests list of `CLAUDE.md`
Uses: the `.claude/skills` symlink of `scripts/link-kb.sh`, the `worktree-end` and `worktree-sync` skills

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** Claude cannot make a branch in the harness main checkout, so it uses a worktree.
  Decision: pending
  Built: 3 of 3
  What Claude thinks the user means: Branches in the harness only come from worktrees.
- **F2.** Worktrees, KBs and other repos work as usual, and the guard never breaks a session.
  Decision: pending
  Built: 4 of 4
  What Claude thinks the user means: The guard blocks only the one bad case and stays out of the way.
- **F3.** I know how to set the guard up.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: A researched, tested way to install it.

## Open questions

- ✅ R6 lets `git checkout <existing-branch>` pass in the main checkout. That moves the main checkout off `main`, which the worktree rule also wants to avoid. Recommendation: keep it out of scope, as the user asked only about making a branch. Yes keeps R6 as it is.
  - Answer: yes, a move to an existing branch passes. R6 stays. Closed 2026-10-29 by the user.
- ✅ R1 refuses the command. A softer form asks the user each time. Recommendation: refuse, with a message that names `EnterWorktree`. The user can still type the command himself (R4).
  - Answer: refuse, with a message that names `EnterWorktree`. R1 stays. Closed 2026-10-29 by the user.
- ✅ R4 lets a git call inside a script pass. A Bash call of a subagent goes through the same `PreToolUse` hook, so the guard covers it too. Recommendation: yes, a subagent counts as Claude.
  - Answer: yes. Written into R4. Closed 2026-10-29 by the user.
- ✅ R6 lets `git checkout <name>` and `git switch <name>` pass. If `<name>` exists only on a remote, git makes a new local branch ([Q6](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q6-which-other-forms-make-a-branch)). Recommendation: refuse it. R6 becomes "a move to an existing local branch", and the hook asks git with `show-ref`.
  - Answer: yes, refuse it. Written into R11, which replaces R6. Closed 2026-10-29 by the user.
- ✅ The landing step of `worktree-end` runs `git checkout "$(…)"` in the main checkout. The hook cannot read that name ([Q4](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q4-does-the-enterworktree-tool-or-a-worktree-skill-run-a-command-that-r1-would-block)). Recommendation: a name the hook cannot read passes, so R2 holds.
  - Answer: yes. Written into R11. Closed 2026-10-29 by the user.
- ✅ R1 lists none of `--track`/`-t` and `git stash branch`, and R5 names neither `GIT_DIR=` nor `--git-dir`. Each one makes a branch or picks the repo ([Q6](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q6-which-other-forms-make-a-branch)). Recommendation: add them to R1 and R5. R5 also gets a limit: a path in a variable, such as `git -C "$H"`, falls back to `cwd` ([Q2](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q2-how-does-the-hook-find-the-repo-a-bash-command-acts-on)).
  - Answer: yes. Written into R8 and R10, which replace R1 and R5. Closed 2026-10-29 by the user.
- ✅ R3 says "in a KB repo, the hook lets each command pass". That can mean a session in a KB, or a command that acts on a KB. With R5, `git -C <harness> checkout -b x` from a KB must be refused. Recommendation: R3 says "a command that acts on a KB repo passes".
  - Answer: yes. Written into R9, which replaces R3. Closed 2026-10-29 by the user.
- ✅ R1 refuses `git branch` with a name and no list or delete flag. That refuses `-u`, `--set-upstream-to`, `--unset-upstream` and `--edit-description`, which make no branch ([Q7](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q7-which-forms-give-a-name-but-make-no-branch)). Recommendation: R1 lets these flags pass.
  - Answer: yes. Written into R8. Closed 2026-10-29 by the user.
- ✅ No doc says if a `!` command of the user reaches a `PreToolUse` hook ([Q5](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md)). Recommendation: `p-build` tests it in a live session. If the hook sees it, R4 becomes a limit, not a goal.
  - Answer: yes, `p-build` tests it. R4 stays as it is until then. Closed 2026-10-29 by the user.
- ✅ If the hook cannot judge a call, the command still needs a result. Examples: a folder that is not a git repo, bad JSON on stdin, or a `git` error. The hook runs on each Bash call in the harness and in each KB, so a bug that refuses would block all Bash. R10 and R14 already pass a path or a name the hook cannot read. Recommendation: the command passes, and the hook prints a warning on stderr. Yes writes this as a new requirement.
  - Answer: yes. Written into R15, which replaces R4, so the count stays at 8. Closed 2026-10-29 by the user.
- ✅ R10 judges each git part of a compound command, and R4 makes `bash x.sh` a limit. No requirement says what happens to a git part inside `bash -c '...'` or `sh -c '...'`. That is the easiest way around the guard. Recommendation: the hook judges it like each other git part. A git alias, such as `git co -b x`, stays a limit. Yes writes this into R10.
  - Answer: yes. Written into R16, which replaces R10. Closed 2026-10-29 by the user.
- ✅ A git command name in a variable, such as `G=git; $G switch x`, and `function f { git switch x; }` pass with no warning. R22 does not name them as limits. Recommendation: add both to the limits of R22. Yes writes them there.
  - Answer: yes. Written into R24, which replaces R22. Closed 2026-10-30 by the user.
- ✅ `echo $'it\'s'; git switch x` fails open: the hook reads the ANSI-C string `$'...'` as an open quote. Recommendation: the raw pass reads `$'...'` as one word, with a test. Yes sends it to `p-design`.
  - Answer: yes. Closed 2026-10-30 by the user.
- ✅ The model's `judge` checks the place before the name, so with a git error it warns for an unreadable name. The code and `1-design.md` pass an unreadable name before any git call, with no warning. Recommendation: `p-design` changes `judge` to check the name first. Yes sends it to `p-design`.
  - Answer: yes. Closed 2026-10-30 by the user.
- A `cd` in the background, as in `cd <KB> & git checkout -b x` from the harness main checkout, moves the folder the hook judges, so the command passes with no warning. Bash runs that `cd` in a subshell. Recommendation: a `cd` before `&` does not last, as a `cd` in a pipeline does not. Yes sends it to `p-design`.
- An unquoted `$(...)` splits a git part, so `git -C $(git rev-parse --show-toplevel) checkout -b x` passes with no warning. Also, R24 says a command substitution is not judged, but the hook does judge an unquoted one, such as `echo $(git switch x)`. Recommendation: an unquoted `$(...)` becomes one unreadable word, as a quoted one does, and R24 keeps it as a limit. Yes sends it to `p-req`, then `p-design`.
- Inside a quoted `$(...)`, the hook reads `$'it\'s'` as an open quote, so the command fails open with a warning. Recommendation: `subst_end` reads `$'...'` as the raw pass does. Yes sends it to `p-design`.
- Three limits are not written in the plan: `pushd <harness>` and `env -C <dir>` pass, and `git init` then `git checkout -b x` in a harness sub-folder is refused. Recommendation: name all three in R24. Yes sends it to `p-req`.
- In the main checkout, `git checkout --detach ronly` is refused, but `--detach` makes no branch. Recommendation: keep the refusal, since git needs no flag of R23 for it and the case is rare. Yes keeps it.
- ✅ In a quoted `$(...)`, the hook does not skip a comment or a `<<<`. A `'` in such a comment, or a `<<<` over several lines, can hide the text after it. Recommendation: `subst_end` skips both, with a test. Yes sends it to `p-design`.
  - Answer: yes. Closed 2026-10-30 by the user.

## Research questions

### User

None.

### Claude

1. ⚠️ open (R21), deferred to `p-build` by the user. Does a `PreToolUse` hook see the Bash calls of a subagent, and the `!` commands of the user? [Q5](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md): subagent yes. The `!` part waits for a live test.
2. answered (R7) Can a `permissions.deny` rule do the job with no script? [Q1](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q1-can-a-permissionsdeny-rule-do-the-job-with-no-script): no. It misses `git -C` and scripts, and cannot tell a worktree.
3. answered (R24) How does the hook find the repo a command acts on? [Q2](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q2-how-does-the-hook-find-the-repo-a-bash-command-acts-on): done. Parse each git part, then ask git. Fall back to `cwd`.
4. answered (R23, R19) Which test tells a main checkout from a linked worktree? [Q3](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q3-which-test-tells-a-main-checkout-from-a-linked-worktree): `--absolute-git-dir` equals the absolute `--git-common-dir` only in the main checkout.
5. answered (R19) Does `EnterWorktree` or a worktree skill run a command that R23 would block? [Q4](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q4-does-the-enterworktree-tool-or-a-worktree-skill-run-a-command-that-r1-would-block): no. One landing command needs a rule, in Open questions.
6. answered (R23, R17) Which other forms make a branch? [Q6](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q6-which-other-forms-make-a-branch): a remote-only name, `--track`, `git stash branch`.
7. answered (R23, R17) Which forms give a name but make no branch? [Q7](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q7-which-forms-give-a-name-but-make-no-branch): `-u`, `--unset-upstream`, `--edit-description`.
8. answered (R23, R18) How does the hook tell the harness from a KB? [Q8](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q8-how-does-the-hook-tell-the-harness-from-a-kb-and-from-any-other-repo): by the `.claude/skills` symlink.
9. answered (R7) Which build answers R7? [Q9](../../../../../../../personal/claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md#q9-which-build-answers-r7-as-a-whole): done. A `PreToolUse` hook on Bash.
