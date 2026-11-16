#!/usr/bin/env bash
# PreToolUse hook on Bash: refuses a new git branch in the main checkout of the harness,
# and git switch everywhere. Each call it cannot judge passes, with a warning.
# Plan: plans/global/components/hooks/components/branch-guard/.
IFS= read -r -d '' input || true
case "$input" in *git*) ;; *) exit 0 ;; esac

IFS= read -r -d '' PY <<'EOF' || true
import json, os, re, shlex, subprocess, sys

def warn(m):
    print(f"branch-guard: {m}", file=sys.stderr)

SEPS = {"&&", "||", ";", ";;", "|", "|&", "&", "\n"}
PIPES = {"|", "|&"}
REDIRS = {">", ">>", "<", "<<<", "<<", ">&", "&>", "<>", ">|", "&>>"}
OPS = ["&>>", "<<<", "&&", "||", ";;", "|&", ">>", ">&", "&>", "<<", "<>", ">|"]
PUNCT = set("();<>|&\n")
SKIP = {"(", ")", "{", "}", "!", "if", "then", "do", "else", "elif", "while", "until"}
# wrapper: its short flags that take a value
WRAPPERS = {"time": "", "command": "", "env": "uCS", "exec": "a", "nohup": "",
            "nice": "n", "timeout": "sk", "caffeinate": "tw"}
# the global options of git that take the next word
GLOBAL_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env", "--attr-source"}
# the long flags of a wrapper that take the next word
LONG_VALUE = {"--signal", "--kill-after", "--unset", "--chdir", "--split-string", "--adjustment"}
VAR = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")

BRANCH_LONG = ["verbose", "quiet", "track", "no-track", "set-upstream-to", "unset-upstream",
               "color", "no-color", "remotes", "contains", "no-contains", "abbrev", "no-abbrev",
               "all", "delete", "move", "copy", "list", "show-current", "create-reflog",
               "edit-description", "force", "merged", "no-merged", "column", "no-column", "sort",
               "points-at", "ignore-case", "omit-empty", "format", "recurse-submodules"]
BRANCH_PASS = {"list", "contains", "no-contains", "merged", "no-merged", "points-at",
               "delete", "set-upstream-to", "unset-upstream", "edit-description"}
CHECKOUT_LONG = ["quiet", "progress", "no-progress", "force", "ours", "theirs", "track",
                 "no-track", "guess", "no-guess", "overlay", "no-overlay", "orphan", "detach",
                 "ignore-skip-worktree-bits", "ignore-other-worktrees", "merge", "conflict",
                 "patch", "pathspec-from-file", "pathspec-file-nul", "overwrite-ignore",
                 "no-overwrite-ignore", "recurse-submodules", "no-recurse-submodules"]
SWITCH_LONG = ["create", "force-create", "orphan", "guess", "no-guess", "discard-changes",
               "quiet", "recurse-submodules", "no-recurse-submodules", "progress",
               "no-progress", "merge", "conflict", "detach", "track", "no-track", "force",
               "ignore-other-worktrees"]

def long_flag(word, names):
    """The full name of a long flag, by git's unique prefix rule, else None."""
    f = word[2:].partition("=")[0]
    if f in names:
        return f
    hits = [n for n in names if n.startswith(f)]
    return hits[0] if len(hits) == 1 else None

def unreadable(s):
    return "$" in s or "`" in s

HEREDOC = re.compile(r"""<<-?[ \t]*\\?(['"]?)([^\s;&|<>()'"\\]+)\1""")

def subst_end(text, i):
    """The index after the ) that closes the $( at i, past nested quotes, parens and heredoc bodies."""
    depth, j, n, q, pending = 0, i + 1, len(text), None, []
    while j < n:
        c = text[j]
        if q:
            if c == "\\" and q == '"':
                j += 2; continue
            if c == q:
                q = None
        elif c == "\\":
            j += 2; continue
        elif c in "'\"":
            q = c
        elif c == "#" and text[j - 1] in " \t\n;&|(":
            j = text.find("\n", j)
            j = n if j < 0 else j
            continue
        elif text.startswith("<<<", j):
            j += 3; continue
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return j + 1
        elif text.startswith("<<", j) and not text.startswith("<<<", j) and (m := HEREDOC.match(text, j)):
            pending.append(m.group(2)); j = m.end(); continue
        elif c == "\n" and pending:
            j += 1
            for word in pending:
                while j < n:
                    end = text.find("\n", j)
                    line = text[j:] if end < 0 else text[j:end]
                    j = n if end < 0 else end + 1
                    if line.lstrip("\t") == word:
                        break
            pending = []
            continue
        j += 1
    return n

def raw_pass(text):
    """Join line ends with a backslash, blank comments, drop heredoc bodies, outside quotes."""
    out, i, n, q, heredocs = [], 0, len(text), None, []
    while i < n:
        c = text[i]
        if q == "'":
            q = None if c == "'" else q
        elif q == '"':
            if c == "\\" and i + 1 < n:
                out.append(c); i += 1; c = text[i]
            elif text.startswith("$(", i):  # a quoted $(...) stays one word: hide its text
                out.append("$_"); i = subst_end(text, i); continue
            elif c == '"':
                q = None
        elif c == "\\" and i + 1 < n:
            if text[i + 1] == "\n":
                i += 2; continue
            out.append(c); i += 1; c = text[i]
        elif text.startswith("$'", i):  # an ANSI-C string: \' does not end it
            j = i + 2
            while j < n and text[j] != "'":
                j += 2 if text[j] == "\\" else 1
            out.append("$_"); i = j + 1; continue
        elif c in "'\"":
            q = c
        elif text.startswith("((", i):  # arithmetic, also in $((: its << is a shift, not a heredoc
            end = text.find("))", i)
            end = n if end < 0 else end + 2
            out.append(text[i:end]); i = end; continue
        elif c == "#" and (not out or out[-1] in " \t\n;&|()"):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("<<", i) and not text.startswith("<<<", i) and (not out or out[-1] != "<"):
            j = i + 2
            strip = j < n and text[j] == "-"
            j += strip
            while j < n and text[j] in " \t":
                j += 1
            m = re.match(r"""\\?(['"]?)([^\s;&|<>()'"\\]+)\1""", text[j:])
            if m:
                heredocs.append((m.group(2), strip))
                out.append(text[i:j + m.end()]); i = j + m.end(); continue
        elif c == "\n" and heredocs:
            out.append(c); i += 1
            for word, strip in heredocs:
                while i < n:
                    end = text.find("\n", i)
                    line = text[i:] if end < 0 else text[i:end]
                    i = n if end < 0 else end + 1
                    if (line.lstrip("\t") if strip else line) == word:
                        break
            heredocs = []
            continue
        out.append(c); i += 1
    return "".join(out)

def tokens(text):
    lex = shlex.shlex(raw_pass(text), posix=True, punctuation_chars="();<>|&\n")
    lex.commenters = ""
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    for tok in lex:
        if tok and set(tok) <= PUNCT:
            while tok:
                op = next((o for o in OPS if tok.startswith(o)), tok[0])
                yield op, True
                tok = tok[len(op):]
        else:
            yield tok, False

def resolve(base, path, cwd):
    if unreadable(path):
        return cwd
    return os.path.normpath(os.path.join(base, os.path.expanduser(path)))

def strip_prefix(words):
    """Drop the shell words before the command, and the wrappers. Returns (env, words)."""
    env, i = {}, 0
    while i < len(words):
        w = words[i]
        if w in SKIP:
            i += 1
        elif VAR.match(w):
            k, _, v = w.partition("="); env[k] = v; i += 1
        elif os.path.basename(w) in WRAPPERS:
            takes = WRAPPERS[os.path.basename(w)]
            timeout = os.path.basename(w) == "timeout"
            i += 1
            while i < len(words) and words[i].startswith("-") and words[i] != "-":
                f = words[i]; i += 1
                short = not f.startswith("--") and f[-1] in takes
                if (short or f in LONG_VALUE) and i < len(words):
                    i += 1
            while i < len(words) and VAR.match(words[i]):
                k, _, v = words[i].partition("="); env[k] = v; i += 1
            if timeout and i < len(words):
                i += 1
        else:
            break
    return env, words[i:]

def drop_redirects(words):
    out, i = [], 0
    while i < len(words):
        w, op = words[i]
        if op and w in REDIRS:
            if out and out[-1].isdigit():
                out.pop()
            i += 2
        else:
            if not op:
                out.append(w)
            i += 1
    return out

def parse(text, folder, cwd, depth=0):
    """The git parts of a command: (words after git, folder, git dir), in order."""
    stack, parts, cmds, cur = [folder], [], [], []
    for tok, op in tokens(text):
        if op and tok in SEPS | {"(", ")"}:
            cmds.append((cur, tok)); cur = []
        else:
            cur.append((tok, op))
    cmds.append((cur, None))
    prev = None
    for cur, nxt in cmds:
        words = drop_redirects(cur)
        env, words = strip_prefix(words)
        piped = prev in PIPES or nxt in PIPES
        if words:
            name = os.path.basename(words[0])
            if name == "cd" and not piped:
                args = [w for w in words[1:] if w not in ("-L", "-P")]
                if not args:
                    stack[-1] = os.path.expanduser("~")
                elif args[0] != "-":
                    stack[-1] = resolve(stack[-1], args[0], cwd)
            elif name in ("bash", "sh", "zsh") and depth == 0:
                rest = words[1:]
                k = next((j for j, w in enumerate(rest) if not w.startswith("--")
                          and w.startswith("-") and "c" in w), None)
                if k is not None:
                    inner = next((w for w in rest[k + 1:] if not w.startswith("-")), None)
                    if inner is not None:
                        parts += parse(inner, stack[-1], cwd, depth + 1)
            elif name == "git":
                parts.append(git_part(words[1:], env, stack[-1], cwd))
        if nxt == "(":
            stack.append(stack[-1])
        elif nxt == ")" and len(stack) > 1:
            stack.pop()
        prev = nxt
    return parts

def git_part(words, env, folder, cwd):
    gitdir = env.get("GIT_DIR")
    i = 0
    while i < len(words):
        w = words[i]
        if w in GLOBAL_VALUE and i + 1 < len(words):
            v = words[i + 1]
            if w == "-C":
                folder = resolve(folder, v, cwd)
            elif w == "--git-dir":
                gitdir = v
            i += 2
        elif w.startswith("--git-dir="):
            gitdir = w.split("=", 1)[1]; i += 1
        elif w.startswith("-"):
            i += 1
        else:
            break
    # git resolves a relative git dir after each -C
    if gitdir is not None and unreadable(gitdir):
        return words[i:], cwd, None
    gitdir = None if gitdir is None else resolve(folder, gitdir, cwd)
    return words[i:], folder, gitdir

def args_before_dashdash(args):
    if "--" in args:
        k = args.index("--")
        return args[:k], args[k + 1:]
    return args, []

def sort(sub):
    """The form of a git part: (form, name)."""
    if not sub:
        return "other", None
    cmd, args = sub[0], sub[1:]
    args, after = args_before_dashdash(args)
    if cmd == "switch":
        new = any((w.startswith("--") and long_flag(w, SWITCH_LONG) in ("create", "force-create", "orphan"))
                  or (w.startswith("-") and not w.startswith("--") and ("c" in w or "C" in w)) for w in args)
        return ("switchNew" if new else "switch"), None
    if after and cmd != "branch":
        return "other", None
    if cmd == "stash" and args[:1] == ["branch"]:
        return "branch", None
    if cmd == "worktree" and args[:1] == ["add"]:
        return "worktreeAdd", None
    if cmd == "checkout":
        names = []
        for w in args:
            if w.startswith("--"):
                if long_flag(w, CHECKOUT_LONG) in ("orphan", "track"):
                    return "branch", None
            elif w.startswith("-") and w != "-":
                if set(w[1:]) & set("bBt"):
                    return "branch", None
            else:
                names.append(w)
        return ("checkoutName", names[0]) if len(names) == 1 else ("other", None)
    if cmd == "branch":
        names, i = [], 0
        while i < len(args):
            w = args[i]; i += 1
            if w.startswith("--"):
                full = long_flag(w, BRANCH_LONG)
                if full in BRANCH_PASS:
                    return "other", None
                if full in ("sort", "format") and "=" not in w:
                    i += 1
            elif w.startswith("-") and w != "-":
                if set(w[1:]) & set("ldDu"):
                    return "other", None
            else:
                names.append(w)
        return ("branch", None) if names or after else ("other", None)
    return "other", None

def git(folder, gitdir, *args):
    pre = ["git", "-C", folder] + ([f"--git-dir={gitdir}"] if gitdir else [])
    r = subprocess.run(pre + list(args), capture_output=True, text=True,
                       env={k: v for k, v in os.environ.items() if not k.startswith("GIT_")})
    if r.returncode:
        raise OSError(r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "git failed")
    return r.stdout

def harness_main(folder, gitdir):
    lines = git(folder, gitdir, "rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir").split("\n")
    d, common = lines[0], lines[1]
    if d != common or not common.endswith("/.git"):
        return False
    root = os.path.dirname(common)
    skills = os.path.join(root, ".claude", "skills")
    return (os.path.isdir(skills) and not os.path.islink(skills)
            and os.path.isfile(os.path.join(root, "scripts", "link-kb.sh")))

def remote_only(folder, gitdir, name):
    refs = set()
    for line in git(folder, gitdir, "for-each-ref", "--format=%(refname) %(symref)",
                    "refs/heads", "refs/remotes").splitlines():
        ref, _, sym = line.partition(" ")
        if not sym:
            refs.add(ref)
    if f"refs/heads/{name}" in refs:
        return False
    return any(f"refs/remotes/{r}/{name}" in refs for r in git(folder, gitdir, "remote").split())

WORKTREE = "Use EnterWorktree to make a worktree, and make the branch there."

def main():
    try:
        data = json.loads(sys.stdin.read())
        text, cwd = data["tool_input"]["command"], data["cwd"]
        if not isinstance(text, str) or not isinstance(cwd, str):
            raise TypeError("command or cwd is not text")
    except Exception as e:
        warn(f"cannot read the hook input ({e}), so the command runs")
        return 0
    try:
        parts = parse(text, cwd, cwd)
    except ValueError as e:
        warn(f"cannot split the command ({e}), so the command runs")
        return 0
    for sub, folder, gitdir in parts:
        form, name = sort(sub)
        shown = "git " + " ".join(sub)
        if form == "switch":
            warn(f"{shown}: git switch is not used here. Use git checkout.")
            return 2
        if form == "switchNew":
            try:
                main_h = harness_main(folder, gitdir)
            except OSError:
                main_h = False
            if main_h:
                warn(f"{shown}: a new branch in the main checkout of the harness. {WORKTREE}")
            else:
                warn(f"{shown}: git switch is not used here. Use git checkout.")
            return 2
        if form not in ("branch", "checkoutName"):
            continue
        if form == "checkoutName" and unreadable(name):
            continue
        try:
            if not harness_main(folder, gitdir):
                continue
            if form == "checkoutName" and not remote_only(folder, gitdir, name):
                continue
        except OSError as e:
            warn(f"{shown}: git failed in {folder} ({e}), so the part passes")
            continue
        why = "makes a branch" if form == "branch" else f"makes a local branch from the remote branch {name}"
        warn(f"{shown}: {why} in the main checkout of the harness. {WORKTREE}")
        return 2
    return 0

try:
    sys.exit(main())
except SystemExit:
    raise
except BaseException as e:
    warn(f"the hook failed ({type(e).__name__}: {e}), so the command runs")
    sys.exit(0)
EOF

printf '%s' "$input" | python3 -I -c "$PY"
rc=$?
[ "$rc" -eq 2 ] && exit 2
[ "$rc" -ne 0 ] && echo "branch-guard: the hook failed (exit $rc), so the command runs" >&2
exit 0
