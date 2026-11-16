# Branch guard: design

## State transitions

The model is [branch-guard.qnt](branch-guard.qnt), module `branchGuard`. It models one run of the hook on one Bash call. It imports nothing. Each git part arrives in the model already sorted into a form, a place and a name: the model does not parse text. The tests of the script check the parse.

```graph
import-graph: architecture.md
```

1. [Received](#received): the hook has the JSON of one Bash call on stdin.
2. [Parsed](#parsed): the hook has split the command into git parts, and takes the next one.
3. [Located](#located): the hook knows the repo of the part, and if it is the main checkout of the harness.
4. [Allowed](#allowed): exit 0. The command runs.
5. [Refused](#refused): exit 2. The command does not run.
6. [Failed open](#failed_open): exit 0 with a warning, since the hook cannot read its input.

## State deep dive

### Received

Claude Code runs `.claude/hooks/branch-guard.sh` before each Bash call, of Claude or of a subagent. The `settings.json` line:

- has the `Bash` matcher and no `if`: an `if` uses the matching of a permission rule, which does not see inside `bash -c` (research Q9),
- finds the script from the git root of the `cwd`, in the shape `tests/global/hooks/test-hook-paths.sh` checks (R2 of the `hooks` plan),
- else from the main checkout of the same repo: the parent of `git rev-parse --path-format=absolute --git-common-dir`. A KB worktree has no `.claude/`, but its main checkout has the links of `scripts/link-kb.sh`,
- else from `$CLAUDE_PROJECT_DIR`, so it runs in each folder, as R21 asks.

1. The script reads all of stdin with `IFS= read -r -d '' input || true`, so no backslash of the JSON is lost. The `read` returns 1 at the end of input, and `|| true` keeps that from ending the script. If the text holds no `git`, a shell `case` exits 0 at once, with no new process (`quickExit`). Most Bash calls end here. Bad JSON with no `git` in it also passes here, with nothing on stderr.
2. Else `printf '%s' "$input" | python3 -I -c "$PY"` hands the JSON to Python, which reads `tool_input.command` and `cwd` with its `json` module. `$PY` is a shell variable that holds the Python program, so the script stays one file on the `Builds:` line. No `jq`.

The script reads the exit of Python: 2 refuses, 0 passes, and each other exit, such as a traceback or no `python3`, passes with a warning. So a failure of the hook itself is failed open, from each state (`crash`).

- **Next:** allowed, if the text holds no `git`. Failed open, if the hook cannot read the command or the `cwd`, or cannot split the command. Allowed, if the command holds no git part (`noGitPart`). Parsed, else.
- **Invariants:** `failsOpen`, `quietWithoutGit`.
- **Expected output:** no output yet. The hook goes on to the parse, or exits 0 for a text with no `git`.

### Parsed

The parse has two passes.

**The raw pass**, over the text, keeps track of quotes:

1. Join each backslash at the end of a line with the next line.
2. Blank each comment, from an unquoted `#` at the start of a word to the end of the line. Keep the new line.
3. Drop each heredoc body, outside quotes: from `<<WORD` or `<<-WORD` to the line that is only `WORD`. A body line such as `git switch main` is text, not a part. A body inside quotes, such as `git commit -m "$(cat <<'EOF' ...)"`, stays in its word. `<<<` is a redirect that takes one word, not a heredoc. A `<<` inside `((...))` or `$((...))` is a shift, not a heredoc. The end word can start with a backslash, as in `<<\EOF`.
4. Inside double quotes, put a placeholder `$_` in place of each `$(...)`, with its nested quotes and parens. Its text is in one word, so its quotes and its commands are not read. Inside the `$(...)`, skip each comment and each `<<<` word, as outside it.
5. Read an ANSI-C string `$'...'` as one word, where `\'` does not end it.

**The token pass** uses Python's `shlex`, with `punctuation_chars=True`, `commenters=''`, and the new line taken out of `whitespace`, so it is a token.

1. Split each punctuation token into shell operators, longest first: `&&`, `||`, `;;`, `|&`, `>>`, `>&`, `&>`, `<<<`, then one character each. `shlex` joins operators that touch, such as `);`.
2. Split the tokens on `&&`, `||`, `;`, `;;`, `|`, `|&`, `&` and new lines into simple commands. A `shlex` error, such as an open quote, is failed open.
3. In each simple command, drop each redirect: `>`, `>>`, `<`, `<<<`, `>&`, `&>`, the word after it, and a file number before it, such as the `2` of `2>/dev/null`.
4. Before the first word, skip `(`, `)`, `{`, `}`, `!`, each `VAR=value` word, and the words `if then do else elif while until`. Skip the wrappers `time`, `command`, `env`, `exec`, `nohup`, `nice`, `timeout` and `caffeinate`, with their flags and the flag values. A long flag such as `--signal KILL` takes the next word as its value. `timeout` also takes a duration word.
5. If the first word has the base name `bash`, `sh` or `zsh`, and a short flag word holds `c`, such as `-c`, `-lc` or `-ec`, parse the next word the same way, one level deep. Its parts start from the folder of the outer command, and a `cd` inside it does not reach the outer command. A deeper `bash -c`, `eval`, `xargs` and a script are a limit.
6. A git part is a simple command whose first word has the base name `git`. A quoted word such as `echo "git switch"` is not a git part.
7. Read the global options of each git part, up to the subcommand. `-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`, `--config-env` and `--attr-source` take a value, with `=` or as the next word. Two `-C` join, as git joins them. Each other leading flag, such as `--no-pager` or `-P`, is skipped. The subcommand is the first word left that is not a flag.
8. Find the folder of the part from a stack of folders. It starts with the `cwd`. A `(` pushes a copy, and a `)` pops it. A `cd <path>` sets the top, except inside a pipeline, where it does not last. Then the `-C` of the part applies. A relative `GIT_DIR` or `--git-dir` resolves against the folder after each `-C`, as git does. Expand a leading `~`, and resolve a relative path against the folder before it. A path or a `GIT_DIR` with `$` or a backtick in it is unreadable, and the folder falls back to the `cwd`.
9. Sort the part into one form. Before the sort, cut `=...` off each long flag. Git takes each unique prefix of a long flag, such as `--or` for `--orphan` and `--tr` for `--track`. So the sort matches each long flag by the same prefix rule, on the refuse side and on the pass side. Only the words before a `--` count. A `checkout` part with words after `--` is a path checkout, so it is `other`. For `git branch`, a word after `--` is a name.

| Form | Text |
|---|---|
| `switch`, `switchNew` | the subcommand `switch`. `switchNew` has a word `-c`, `-C`, or a prefix of `--create`, `--force-create` or `--orphan` |
| `branch` | `checkout` with a short flag word that holds `b`, `B` or `t`, such as `-b`, `-qb` or `-bx`, or a prefix of `--orphan` or `--track`. `stash branch`. `branch` with a name, as the next lines say |
| `checkoutName` | `checkout` with one word that is not a flag, with or without other flags such as `-q`, `--quiet` or `-f` |
| `worktreeAdd` | `worktree add`, with each flag |
| `other` | each other form, such as `branch --list`, `branch -u origin/x`, `checkout -- file`, `checkout HEAD -- file`, `fetch`, `status` |

For `git branch`:

- A delete or upstream flag of R23 makes the part `other`.
- A list-mode flag makes the part `other`: `--list`, `-l`, `--contains`, `--no-contains`, `--merged`, `--no-merged` and `--points-at`. Its value or pattern is not a name.
- Each other flag of R23, such as `-v`, `-vv`, `--sort`, `--format` and `--column`, does not make a list. Git makes a branch from a name after it, such as `git branch -v x`. So the hook drops the flag and its value, and if a word is left, it is a name.
- With no name, `git branch` lists, so it is `other`.

A short flag word that holds `b`, `B` or `t` can refuse a command that makes no branch. That refuses too much, not too little.

- **Next:** for `switch` or `switchNew`, refused (`refuseSwitch`). For `switchNew`, a git call as in Located picks the message first: `EnterWorktree` in the main checkout of the harness, else `git checkout`. A failed call picks `git checkout`. Located, if the part is `branch` or `checkoutName` (`locate`). Else the next part, or allowed after the last one (`passForm`).
- **Invariants:** `switchRefused`, `worktreeAddPasses`.
- **Expected output:** no output. The command is a list of parts, each with its form: `switch`, `switchNew`, `branch`, `checkoutName`, `worktreeAdd` or `other`.

### Located

The hook runs git in the folder of the part, with the `GIT_DIR` or `--git-dir` of the part if it has one. For each part it runs the first call. For `checkoutName` it also runs the other two:

```sh
git -C <folder> rev-parse --path-format=absolute --git-dir --git-common-dir
git -C <folder> for-each-ref --format='%(refname) %(symref)' refs/heads refs/remotes
git -C <folder> remote
```

- **Main checkout:** the two lines of the first call are equal (research Q3). In a linked worktree, the git dir is `<common>/worktrees/<name>`.
- **Clone root:** the parent of the common dir, when the common dir ends in `/.git`. It is not `--show-toplevel`: with `GIT_DIR` set from another folder, `--show-toplevel` gives that folder (Appendix, test 1).
- **Harness:** the clone root holds `.claude/skills` as a real folder, not a symlink, and `scripts/link-kb.sh`.
- **Remote-only name**, with no fetch. Python skips each ref with a `%(symref)`, such as `refs/remotes/origin/HEAD`, so `git checkout HEAD` passes. The name is remote-only if no ref is `refs/heads/<name>`, and a ref is `refs/remotes/<remote>/<name>`, for a remote that `git remote` names. A prefix such as `origin/feat/x` for `feat` does not count. A name with `$` or a backtick is unreadable, and passes, with no warning.
- **A failed call**, any of the three, is the git error case, so it never refuses.

The action `judge` decides:

- a failed git call: the part passes, with a warning on stderr,
- the main checkout of the harness and `branch`: refused,
- the main checkout of the harness, `checkoutName` and a remote-only name: refused,
- else the part passes.

- **Next:** refused, or the next part, or allowed after the last one.
- **Invariants:** `branchRefusedInHarnessMain`, `remoteOnlyRefused`, `refusesOnlyForCause`, `otherReposPass`, `gitErrorWarns`.
- **Expected output:** no output for a part that passes. A part that is refused or fails open ends in the next state, which prints its own line.

### Allowed

Each part passed. The hook exits 0.

- **Invariants:** `exitIsZeroOrTwo`.
- **Expected output:** exit 0. Nothing on stderr, or one warning line per part whose git call failed, starting with `branch-guard:`. An unreadable name or path passes with no warning, so the landing step of `worktree-end` stays quiet.

### Refused

The first part the hook refuses ends the run. The hook exits 2, so Claude Code blocks the call and shows the message to Claude.

| Cause | Message names |
|---|---|
| `switch` | `git checkout` |
| `switchNew` in the main checkout of the harness | `EnterWorktree` only |
| `branch`, or a remote-only `checkoutName`, in the main checkout of the harness | `EnterWorktree` |

For `switchNew`, the hook runs the test of Located only to pick the message. If that git call fails, the message names `git checkout`.

- **Invariants:** `messageFits`, `exitIsZeroOrTwo`.
- **Expected output:** exit 2, and one line on stderr: `branch-guard: <the part>: <why>. <what to do>`.

### Failed open

The text holds `git`, and the script cannot go on. The causes:

- bad JSON, or no `tool_input.command` or `cwd`,
- a `shlex` error, such as an open quote,
- a failure of the script itself, such as a traceback. It exits 0, so a bug in the hook never blocks all Bash.

- **Invariants:** `failsOpen`.
- **Expected output:** exit 0, and one warning line on stderr.

## Build checks

`tests/global/hooks/test-branch-guard.sh` makes git repos in a temp folder:

- a harness repo: its skills folder is a folder, and it has a `link-kb.sh` script,
- a linked worktree of the harness repo,
- a KB repo: its skills folder is a symlink,
- a bare origin with a branch that only it has.

It pipes hook JSON into `.claude/hooks/branch-guard.sh` and checks the exit code and stderr. One case per `run` of the model, and one per invariant:

| Case | Model |
|---|---|
| `git switch x` in the KB: exit 2, names `git checkout` | `switchInKbTest`, `switchRefused` |
| `git switch -c x` in the main checkout: exit 2, names only `EnterWorktree` | `switchNewInMainTest`, `messageFits` |
| each form of `branch` in the main checkout: exit 2 | `branchInMainTest`, `branchRefusedInHarnessMain` |
| the same forms in the linked worktree: exit 0 | `branchInWorktreeTest` |
| `git checkout <remote-only>`: exit 2, `git checkout <local>`, a tag, `-`, `origin/x`, `-- file`: exit 0 | `remoteOnlyTest`, `remoteOnlyRefused` |
| the landing line of `worktree-end`, word for word from its `SKILL.md`, step 5, in the main checkout: exit 0 | `unreadableNameTest`, `refusesOnlyForCause` |
| `git checkout "$X"` from a folder outside a repo: exit 0, nothing on stderr | `unreadableGitErrorTest`, `gitErrorWarns` |
| `git checkout -b x` in the KB, and in its linked worktree: exit 0 | `branchInKbTest`, `otherReposPass` |
| a `cwd` outside a repo, then a branch in the main checkout: warning, then exit 2 | `gitErrorTest`, `gitErrorWarns` |
| bad JSON, and JSON with no command: exit 0 with a warning | `badInputTest`, `failsOpen` |
| `git worktree add -b`, `-B`, and a remote-only name, in each checkout: exit 0 | `worktreeAddTest`, `worktreeAddPasses` |
| `ls`, and bad JSON with no `git` in it: exit 0, nothing on stderr | `quickExitTest`, `quietWithoutGit` |
| `echo "git switch"`: exit 0, nothing on stderr | `noGitPartTest` |
| an open quote, such as `echo it's` with `git` after it: exit 0 with a warning | `failsOpen` |
| a Python that exits 1 in the middle of a run, made with a stub `python3` on `PATH`: exit 0 with a warning | `crashTest`, `failsOpen` |
| each exit is 0 or 2 | `exitIsZeroOrTwo` |

The parse has its own tests, one for each word of R23 and R24. Each test runs in the main checkout of the harness, unless its row names another folder.

| Text | Exit |
|---|---|
| `git checkout` with `-b x`, `-B x`, `--orphan x`, `--track origin/x`, `-t origin/x`, `-qb x`, `-bx`, `--orph x`, `--or x`, `--orphan=x`, `--tr origin/x`, `--track=direct origin/x` | 2 |
| `git stash branch x` | 2 |
| `git branch x`, `git branch x -f`, `git branch -f x`, `--force x`, `-m a b`, `-M a`, `--move a b`, `-c a b`, `-C a b`, `--copy a b`, `-v x`, `--sort=x y`, `--format '%(refname)' x` | 2 |
| `git branch` with `--list`, `--list 'foo*'`, `-l`, `-a`, `-r`, `-v`, `-vv`, `--contains main`, `--no-contains main`, `--merged main`, `--no-merged main`, `--points-at HEAD`, `--sort=-committerdate`, `--sort -committerdate`, `--format '%(refname)'`, `--format=%(refname)`, `--column`, `--show-current`, `-d x`, `-D x`, `--delete x`, `--del x`, `--mer main`, `-u origin/x`, `--set-upstream-to=origin/x`, `--unset-upstream`, `--edit-description` | 0 |
| `git checkout -- file`, `git checkout main -- file`, `git checkout HEAD -- file`, `git checkout HEAD`, `git checkout feat` where only `origin/feat/x` exists | 0 |
| `ls  # list` then `git checkout -b x` on the next line, `git \` then `checkout -b x` on the next line, `(cd <kb> && ls); git checkout -b x`, `make \|& git switch y` | 2 |
| `(cd <kb> && git pull) ; git checkout -b x`, from the main checkout | 2 |
| `cd <harness> && bash -c 'git branch x'`, from the KB | 2 |
| `timeout 30 git switch x`, `nice git switch x`, `env -i git switch x`, `time -p git switch x` | 2 |
| `cat > n.md <<EOF` with a body line `Don't use git switch`, then `EOF` | 0, no warning |
| `cat <<< x` then `git switch y` on the next line | 2 |
| `git -C <harness> branch x`, `GIT_DIR=<harness>/.git git branch x` and `git --git-dir <harness>/.git branch x`, each from the KB | 2 |
| `GIT_DIR=<harness>/.git/worktrees/<wt> git branch x`, from the KB | 0 |
| `cd <harness> && git branch x`, `cd ~/<path to harness> && git branch x` with `HOME` set, `(cd <harness> && git branch x)`, from the KB | 2 |
| `a && git checkout -b x`, `sleep 1 & git checkout -b x`, two lines with `git checkout -b x` on the second | 2 |
| `bash -c 'git checkout -b x'`, `bash -lc '...'`, `/bin/sh -c "git switch y"`, `zsh -c '...'` | 2 |
| `command git switch x`, `env GIT_DIR=x git switch y`, `/usr/bin/git switch x`, `if true; then git switch x; fi`, `{ git switch x; }` | 2 |
| `git -c core.x=y checkout -b x`, `git --no-pager switch x`, `git -P switch x` | 2 |
| `git checkout feat 2>/dev/null` and `git checkout -q feat`, where only `origin/feat` exists | 2 |
| `cat > n.md <<'EOF'` with a body line `git switch main` | 0 |
| `git -C "$H" checkout -b x` from the KB, with `H` the harness: the `cwd` is the KB | 0 |
| `git branch -- x`, `git --attr-source HEAD checkout -b x`, `git --config-env a=B checkout -b x` | 2 |
| `GIT_DIR=.git git -C <harness> branch x`, from the KB | 2 |
| `timeout --signal KILL 30 git switch x` | 2 |
| `echo $((1<<2))` then `git switch x` on the next line, `(( n = 1 << 3 ))` then `git switch x` on the next line | 2 |
| `cat <<\EOF`, a body line, `EOF`, then `git checkout -b x` | 2 |
| `cd <harness> && GIT_DIR="$X" git branch x`, from the KB: the folder is the `cwd` | 0 |
| `git commit -m "$(cat <<'EOF'` with a body line `Hook: refuse "cd x && git switch y"`, then `EOF` and `)"` | 0 |
| `echo $'it\'s'; git switch x` | 2 |
| `echo "$(ls # it's` then `)"` and `git switch x` on the next lines, `echo "$(cat <<< "a"` then `)"` and `git switch x` on the next lines | 2 |

Three more checks in the same test file:

- `.claude/settings.json` has a `PreToolUse` entry on `Bash` that runs `branch-guard.sh`, with no `if`, and with the fall back to `$CLAUDE_PROJECT_DIR`.
- The command of that entry, run in a folder with no script and with `CLAUDE_PROJECT_DIR` set to the harness, refuses `git switch x`.
- `.claude/CLAUDE.md` says that Claude makes a harness branch only with a worktree, in "Branches and worktrees: harness only".

`tests/global/hooks/test-hook-paths.sh` already checks that the new line finds its script.

No check can see two rules:

- whether a `!` command of the user reaches the hook. `p-build` tests it in a live session (Research question 1).
- whether a subagent's Bash call reaches the hook. The docs say yes. `p-build` can test it in the same live session.

- **Model checks:** `npx quint run plans/global/components/hooks/components/branch-guard/branch-guard.qnt --invariant=allInvariants` checks these in every state of a walk: none new. The steps and runs with no invariant of their own: `crash`, `done`, `exitIsZeroOrTwo`, `failOpen`, `judge`, `locate`, `noGitPart`, `parse`, `passForm`, `quickExit`, `refuseSwitch`, `start`, `startWith`.

## Coverage

| Requirement | Held by |
|---|---|
| R7 | Not in the model: a research requirement. The research answers it, and this design is the build it names. The `!` part waits for `p-build`. |
| R23 | `branchRefusedInHarnessMain`, `messageFits`, `branchInMainTest`. The list of forms is in the parse cases of Build checks. |
| R13 | `switchRefused`, `messageFits`, `switchInKbTest`, `switchNewInMainTest` |
| R21 | `failsOpen`, `quietWithoutGit`, `gitErrorWarns`, `badInputTest`, `quickExitTest`, `gitErrorTest`. The `settings.json` line is a Build check, not in the model. |
| R24 | Not in the model, which takes each part already sorted. The parse cases of Build checks hold it. |
| R17 | `remoteOnlyRefused`, `refusesOnlyForCause`, `remoteOnlyTest`, `unreadableNameTest` |
| R18 | `otherReposPass`, `refusesOnlyForCause`, `branchInKbTest` |
| R19 | `worktreeAddPasses`, `refusesOnlyForCause`, `branchInWorktreeTest`, `worktreeAddTest`. The line in `.claude/CLAUDE.md` is a Build check. |
| allowed | the end of the run: see Risks |
| failed_open | the end of the run: the run `crashTest` |
| refused | the end of the run: see Risks |

## Risks

- **The parse misreads a form.** `shlex` sees quotes, but not every shell form. An unsorted part is `other` and passes, by the fail-open choice of R21. So a misread lets a branch through with no sign. Each form of R23 has a parse case in the test file, and the parse sorts short flag words wide, so it refuses too much, not too little.
- **No script in the folder.** A linked worktree of a KB has no `.claude/`, since a KB gitignores it. Another repo, or a harness worktree made before this hook is on `main`, has no script either. The fall back of R21 runs the script of the project folder there. If the project folder has none too, the hook command fails and the call runs. That is a limit.
- **`test-hook-paths.sh` and the fall back.** That suite of the `hooks` plan checks the shape of each hook line. If it refuses the fall back, `p-build` names it for a round on the `hooks` plan, whose R2 needs a line for this exception.
- **`git checkout <commit> -- <file>` and `git checkout -- <file>`.** A word after `--` is a path, not a name. The parse reads only the words before `--`.
- **A flag after the name**, such as `git branch x -f`. The parse reads all words of the part, not only the first.
- **Two `-C` flags.** Git joins them: `git -C a -C b` acts on `a/b`. The parse joins them the same way.
- **The limits of R24:** a git alias, a deeper `bash -c`, `eval`, `xargs`, a script (`bash x.sh`), a heredoc fed to a shell (`bash <<EOF`), a command substitution (`$(git ...)` or backticks), a git command name in a variable (`$G switch x`), a function made with `function`, and a path in a variable are not judged. A path in a variable falls back to the `cwd`.
- **A slow hook.** It runs on each Bash call. The first test is a shell `case` on the word `git`, after the `read` builtin, with no process start. Only a command with `git` in it starts Python.
- **A bug that refuses each call.** Each error path exits 0 with a warning (R21). Only an exit 2 of the Python refuses. The test file has a case for bad JSON, an open quote and a folder outside a repo.
- **The `!` commands of the user.** If the hook sees them, it judges them as calls of Claude. That is a limit of R21, tested in `p-build`.
- **A name that is also a tag**, when only a remote has the branch: refused, as the user picked in R17. It refuses too much, not too little.
- **Fetch, then check out.** In `git fetch && git checkout feat`, `feat` is on no remote ref yet when the hook runs, so the part passes. The fetch then makes `origin/feat`, and the checkout makes a local branch. That is a limit of R17.
- **`GIT_DIR` set apart from the git part**, such as `export GIT_DIR=<harness>/.git; git branch x` from a KB. The hook judges the `cwd`, so it passes. That is a limit of R24, like a path in a variable.
- **Other wrappers**, such as `xargs git ...` or `sudo git ...`, are not skipped. Their git part passes. That is a limit of R24.
- **`git branch -v x` makes a branch.** Git makes a branch from a name after `-v`, `-vv`, `--sort`, `--format` or `--column`, so R23 passes them only with no name. No test checks this read of the code of git: `p-build` tests it in a temp repo.

## Appendix

1. **Clone root under `GIT_DIR`, 2026-10-29, git 2.50.1.** Make repo `a` with a linked worktree `wt`, and repo `b`. From `b`, run each of these and compare the two lines:

   ```sh
   GIT_DIR=../a/.git git rev-parse --path-format=absolute --git-dir --git-common-dir   # equal: main checkout of a
   git --git-dir=../a/.git rev-parse --path-format=absolute --git-dir --git-common-dir  # equal
   GIT_DIR=../a/.git/worktrees/wt git rev-parse --path-format=absolute --git-dir --git-common-dir  # differ: linked
   git -C / rev-parse --git-dir   # exit 128: not a repo
   GIT_DIR=../a/.git git rev-parse --show-toplevel   # prints b, the wrong root
   ```

2. The research page: `claude-research/staging/2026-10-29-branch-guard/branch-guard.staging.md` in the `personal` KB. Q2 the parse, Q3 the main checkout test, Q6 and Q7 the forms, Q8 the harness test, Q9 the hook with no `if`.
3. The hook input and exit 2: https://code.claude.com/docs/en/hooks.md, retrieved 2026-10-29, source [2] of the research page.
4. The model checks, from the harness root:

   ```sh
   npx quint typecheck plans/global/components/hooks/components/branch-guard/branch-guard.qnt
   npx quint test plans/global/components/hooks/components/branch-guard/branch-guard.qnt --main=branchGuard
   npx quint run plans/global/components/hooks/components/branch-guard/branch-guard.qnt --main=branchGuard --invariant=allInvariants --max-samples=3000
   npx quint run plans/global/components/hooks/components/branch-guard/branch-guard.qnt --main=branchGuard --invariant=negativeControl   # must report a violation
   ```
