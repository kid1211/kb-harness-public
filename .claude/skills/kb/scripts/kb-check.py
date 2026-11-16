#!/usr/bin/env python3
"""The one holder of the KB file rules.

Usage:
  kb-check.py area|date|score|sources|all|todo <kb>
  kb-check.py file <path>
  kb-check.py guard    < PreToolUse hook JSON   (Write, Edit, MultiEdit)
  kb-check.py after    < PostToolUse hook JSON  (Write, Edit, MultiEdit; Bash with $KB_BASH_MARKER)
  kb-check.py --test

A rule prints one line per problem, `<path>: <problem>`, and exits 1 if it
found one. `todo` is a listing and exits 0. `all` runs the four rules, then
lists each consolidated page with an uncommitted change.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

DATE = re.compile(r"^(\d{4}(-\d{2}){0,2}([-_. ]|$)|undated-)")
DAY = r"\d{4}-\d{2}-\d{2}"
SCORE_LINE = re.compile(rf"^Confidence: [1-3], {DAY}\s*$")
HEADING = re.compile(r"^(#+)\s+(.*?)\s*$")
TODO = re.compile(r"TODO\((P[1-3])\):\s*(.*)")
CITE = re.compile(r"\[(\d+)\](?![(\[])")
ENTRY = re.compile(r"^\s*(?:[-*]\s*)?(?:\[(\d+)\]|(\d+)\.)\s")
LINK = re.compile(r"\]\(([^)\s]+)\)")
URL = re.compile(r"^https?://")


def kb_root(path):
    """The KB a path is in: the nearest folder whose `.claude/CLAUDE.md` is a symlink into the harness."""
    for d in Path(os.path.abspath(path)).parents:
        if (d / ".claude" / "CLAUDE.md").is_symlink():
            return d
    return None


def area(rel):
    """kbPage.areaOf: exempt, source, staging, consolidated, or none."""
    parts = Path(rel).parts
    if any(p.startswith(".") for p in parts) or parts[0] == "plans" or parts[-1] == "CLAUDE.md":
        return "exempt"
    bits = parts[-1].split(".")
    if len(bits) >= 3 and bits[-2] in ("source", "staging"):
        return bits[-2]
    return "consolidated" if bits[-1] == "md" and len(bits) >= 2 else "none"


def dated(rel):
    """A source name, or a folder it is in, starts with YYYY, YYYY-MM, YYYY-MM-DD or undated-."""
    return any(DATE.match(p) for p in Path(rel).parts)


def files(kb):
    for d, dirs, names in os.walk(kb):
        dirs[:] = sorted(x for x in dirs if not x.startswith(".") and not (Path(d) == Path(kb) and x == "plans"))
        for n in sorted(names):
            p = Path(d) / n
            yield p, p.relative_to(kb)


def body(text):
    """Lines outside code fences, with inline code blanked."""
    out, fence = [], False
    for line in text.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
            out.append("")
        else:
            out.append("" if fence else re.sub(r"`[^`]*`", "", line))
    return out


def score_problems(text):
    """R22: a root score with its date, in the frontmatter or on the line under the title."""
    out = []
    if text.startswith("---\n") and (end := text.find("\n---", 3)) > 0:
        meta = dict(re.findall(r"^(\w+):\s*(.*?)\s*$", text[4:end], re.M))
        if not re.fullmatch(r"[1-3]", meta.get("confidence", "")):
            out.append("no root score: frontmatter needs `confidence: 1`, `2` or `3`")
        if not re.fullmatch(DAY, meta.get("confirmed", "")):
            out.append("no confirmed date: frontmatter needs `confirmed: YYYY-MM-DD`")
        lines = text[end + 4:].split("\n")
    else:
        lines = text.split("\n")
        title = next((i for i, l in enumerate(lines) if l.startswith("# ")), None)
        nxt = next((l for l in lines[title + 1:] if l.strip()), "") if title is not None else ""
        if not SCORE_LINE.match(nxt):
            out.append("no root score: add frontmatter, or `Confidence: N, YYYY-MM-DD` under the title")
    for line in body("\n".join(lines)):
        if line.startswith("Confidence:") and not SCORE_LINE.match(line):
            out.append(f"bad score line `{line.strip()}`: write `Confidence: 1|2|3, YYYY-MM-DD`")
    return out


def source_problems(text, path, kind):
    """R4: each [n] has an entry under Sources that links a `.source.` file that exists. Staging may also cite a URL with its retrieval date, a repo path or a command, as p-research writes them."""
    lines, entries, cited, level = body(text), {}, set(), None
    for line, raw in zip(lines, text.split("\n")):
        h = HEADING.match(line)
        if h:
            level = len(h.group(1)) if h.group(2).lower() == "sources" else (level if level and len(h.group(1)) > level else None)
            continue
        if level:
            m = ENTRY.match(line)
            if m:
                entries[m.group(1) or m.group(2)] = raw
        else:
            cited.update(CITE.findall(line))
    out = [f"[{n}] has no entry under a Sources heading" for n in sorted(cited - entries.keys(), key=int)]
    for n, line in sorted(entries.items(), key=lambda e: int(e[0])):
        # ponytail: any code span passes on staging (a repo path or a command), not checked that it exists
        ok = kind == "staging" and ("`" in line or (re.search(r"https?://", line) is not None and re.search(DAY, line) is not None))
        for t in LINK.findall(line):
            if URL.match(t):
                ok = ok or (kind == "staging" and re.search(DAY, line) is not None)
            else:
                f = (Path(path).parent / t.split("#")[0]).resolve() if not os.path.isabs(t) else Path(t)
                ok = ok or (".source." in f.name and os.path.lexists(f))
        if not ok:
            out.append(f"source [{n}] links no `.source.` file that exists" + (", or a URL with its retrieval date" if kind == "staging" else ""))
    return out


def check(path, rel, text=None, rules=("area", "date", "score", "sources")):
    """The problems of one file. `text` stands in for the file's content, for the guard."""
    a, out = area(rel), []
    if a == "exempt":
        return out
    if "area" in rules and a == "none":
        out.append("no area: name it `name.source.<ext>`, `name.staging.<ext>`, or a plain `.md` for a consolidated page")
    if "date" in rules and a == "source" and not dated(rel):
        out.append("source with no event date: start its name or its folder's name with YYYY-MM-DD, YYYY-MM, YYYY or undated-")
    if a in ("staging", "consolidated") and rel.suffix == ".md":
        if text is None:
            text = Path(path).read_text(errors="replace")
        if "score" in rules and a == "consolidated":
            out += score_problems(text)
        if "sources" in rules:
            out += source_problems(text, path, a)
    return out


def run_rules(kb, rules):
    bad = 0
    for p, rel in files(kb):
        for problem in check(p, rel, rules=rules):
            print(f"{rel}: {problem}")
            bad = 1
    return bad


def todo(kb):
    """R23: every TODO(Pn) mark, P1 first, and each undated- source as P3."""
    items = []
    for p, rel in files(kb):
        a = area(rel)
        if a == "source" and any(x.startswith("undated-") for x in rel.parts):
            items.append(("P3", str(rel), "", "event date not known"))
        if a in ("staging", "consolidated") and rel.suffix == ".md":
            head = ""
            for line in body(p.read_text(errors="replace")):
                h = HEADING.match(line)
                head = h.group(2) if h else head
                if m := TODO.search(line):
                    items.append((m.group(1), str(rel), head, m.group(2)))
    for pr, f, h, t in sorted(items):
        print(f"{pr} {f}" + (f" [{h}]" if h else "") + f": {t}")
    return 0


def uncommitted(kb):
    out = subprocess.run(["git", "-C", str(kb), "status", "--porcelain"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        rel = Path(line[3:].strip('"'))
        if area(rel) == "consolidated":
            print(f"{rel}: consolidated page with an uncommitted change: the user checks it")


def composed(inp, path):
    """The page as it will be after this Write, Edit or MultiEdit, or None if an edit does not apply."""
    t = inp.get("tool_input", {})
    if inp.get("tool_name") == "Write":
        return t.get("content", "")
    text = Path(path).read_text(errors="replace") if os.path.exists(path) else ""
    for e in t.get("edits") or [t]:
        old, new = e.get("old_string", ""), e.get("new_string", "")
        if old not in text:
            return None
        text = text.replace(old, new) if e.get("replace_all") else text.replace(old, new, 1)
    return text


def decide(kind, reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": kind, "permissionDecisionReason": reason}}))


def guard(inp):
    """kbWrite: classify, sourceWith, writeStaging, askJoeWith."""
    path = inp.get("tool_input", {}).get("file_path", "")
    kb = kb_root(path) if path else None
    if not kb:
        return 0
    rel = Path(os.path.abspath(path)).relative_to(kb)
    a = area(rel)
    if a == "none":
        decide("deny", f"{rel}: " + check(path, rel, rules=("area",))[0])
    elif a == "source" and not dated(rel):
        decide("deny", f"{rel}: " + check(path, rel, rules=("date",))[0])
    elif a == "source" and os.path.lexists(path):
        decide("ask", f"{rel} is source: it stays as it came in. The user confirms this change")
    elif a == "consolidated":
        text = composed(inp, path)
        if text is None:
            return 0  # the edit does not apply, and the tool itself fails
        problems = check(path, rel, text=text)
        if problems:
            decide("deny", f"{rel} as it would be: " + "; ".join(problems) + ". The user is not asked until the page has its score and sources")
        else:
            decide("ask", f"{rel} is a consolidated page: the user confirms each change")
    return 0


def context(text):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}))


def confirmed_headings(folder):
    out = []
    for p in sorted(Path(folder).glob("*.md")):
        if area(Path(p.name)) == "consolidated":
            lines = p.read_text(errors="replace").split("\n")
            out.append(f"- {p.name}: " + "; ".join(l.strip() for l in lines if l.startswith("#") or l.startswith("Confidence:") or l.startswith("confidence:")))
    return out


def after(inp):
    """Written: the check after a write. Flagged: each KB file a Bash command changed."""
    msgs = []
    if inp.get("tool_name") == "Bash":
        marker = os.environ.get("KB_BASH_MARKER", "")
        if not os.path.exists(marker):
            return 0
        since = os.stat(marker).st_mtime_ns
        home = Path(os.environ.get("KB_HOME", Path.home() / "second-brain"))
        for kb in sorted(d for d in home.iterdir() if (d / ".claude" / "CLAUDE.md").is_symlink()):
            for p, rel in files(kb):
                if area(rel) != "exempt" and os.lstat(p).st_mtime_ns > since:
                    tag = "a consolidated page changed outside the guard: tell the user" if area(rel) == "consolidated" else "changed by Bash"
                    problems = check(p, rel) if p.exists() else []
                    msgs.append(f"{kb.name}/{rel}: {tag}" + ("; " + "; ".join(problems) if problems else ""))
        if msgs:
            context("kb: this Bash command changed KB files past the PreToolUse hook. Write KB files with Write or Edit.\n" + "\n".join(msgs))
        return 0
    path = inp.get("tool_input", {}).get("file_path", "")
    kb = kb_root(path) if path else None
    if not kb or not os.path.exists(path):
        return 0
    rel = Path(os.path.abspath(path)).relative_to(kb)
    problems = check(path, rel)
    if problems:
        msgs.append(f"kb-check: {rel}: " + "; ".join(problems) + ". Fix it.")
    if area(rel) == "staging":
        heads = confirmed_headings(Path(path).parent)
        if heads:
            msgs.append("kb: compare what you wrote with the confirmed pages of this topic. If a fact disagrees, write "
                        "`TODO(P1): conflict with <page>#<heading>: <both values and sources>` in the staging page, "
                        "tell the user, and propose /op-fork-new-wt. Do not edit the consolidated page.\n" + "\n".join(heads))
    if msgs:
        context("\n".join(msgs))
    return 0


def main(argv):
    if argv == ["--test"]:
        return selftest()
    if argv in (["guard"], ["after"]):
        try:
            inp = json.load(sys.stdin)
        except ValueError:
            return 0
        return guard(inp) if argv[0] == "guard" else after(inp)
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd, arg = argv
    if cmd == "file":
        kb = kb_root(arg)
        if not kb:
            print(f"{arg}: not in a KB", file=sys.stderr)
            return 2
        rel = Path(os.path.abspath(arg)).relative_to(kb)
        problems = check(arg, rel)
        for p in problems:
            print(f"{rel}: {p}")
        return 1 if problems else 0
    kb = Path(arg)
    if cmd == "todo":
        return todo(kb)
    if cmd == "all":
        bad = run_rules(kb, ("area", "date", "score", "sources"))
        uncommitted(kb)
        return bad
    if cmd in ("area", "date", "score", "sources"):
        return run_rules(kb, (cmd,))
    print(__doc__, file=sys.stderr)
    return 2


def selftest():
    """One bad tree per rule, and one good tree that passes all. Each case names its model part."""
    import io
    from contextlib import redirect_stdout

    harness = Path(tempfile.mkdtemp())
    (harness / "CLAUDE.md").write_text("x")

    def kb(tree):
        root = Path(tempfile.mkdtemp())
        (root / ".claude").mkdir()
        (root / ".claude" / "CLAUDE.md").symlink_to(harness / "CLAUDE.md")
        for rel, text in tree.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text)
        return root

    def run(*argv, stdin=None):
        buf, old = io.StringIO(), sys.stdin
        sys.stdin = io.StringIO(stdin) if stdin is not None else old
        try:
            with redirect_stdout(buf):
                code = main(list(argv))
        finally:
            sys.stdin = old
        return code, buf.getvalue()

    page = "---\nconfidence: 3\nconfirmed: 2026-10-23\n---\n# Member\n\n## Meds\nConfidence: 2, 2026-10-23\n\nAspirin [1].\n\n## Sources\n\n1. [visit](2026-10-01-visit/note.source.md)\n"
    good = {
        "member/colon/status.md": page,
        "member/colon/2026-10-01-visit/note.source.md": "x",
        "member/colon/2026-10-01-visit/IMG_1.source.jpeg": "x",
        "member/colon/undated-scan.source.pdf": "x",
        "member/colon/trend.staging.md": "New [1] [2] [3].\n\nTODO(P2): get the lab date\n\n## Sources\n\n- [1] [web](https://example.com) retrieved 2026-10-23\n- [2] https://example.org, retrieved 2026-10-24 10:00 EDT.\n- [3] `scripts/x.sh:4` in this repo.\n",
        "member/CLAUDE.md": "x",
        ".vscode/settings.json": "{}",
        "plans/x/0-index.md": "x",
    }
    cases = []
    root = kb(good)
    cases.append(("good tree passes all (safety)", run("all", str(root))[0] == 0))
    cases.append(("todo lists P2 then undated P3", [l.split()[0] for l in run("todo", str(root))[1].splitlines()] == ["P2", "P3"]))
    bad = {
        ("area", "everyFileHasArea"): {"member/photo.jpeg": "x"},
        ("date", "sourceHasDate"): {"member/scan.source.pdf": "x"},
        ("score", "noRootScoreTest"): {"member/s.md": "# Member\n\nNo score.\n"},
        ("score", "bad confirmed date"): {"member/s.md": "---\nconfidence: 3\n---\n# Member\n"},
        ("score", "score out of 1 to 3"): {"member/s.md": "# Member\nConfidence: 5, 2026-10-23\n"},
        ("score", "bad heading score line"): {"member/s.md": "# Member\nConfidence: 2, 2026-10-23\n\n## A\nConfidence: high\n"},
        ("sources", "citesSource: no entry"): {"member/s.md": "# Member\nConfidence: 2, 2026-10-23\n\nX [1].\n"},
        ("sources", "citesSource: missing file"): {"member/s.md": "# Member\nConfidence: 2, 2026-10-23\n\nX [1].\n\n## Sources\n\n1. [a](gone.source.md)\n"},
        ("sources", "consolidated cites a URL"): {"member/s.md": "# Member\nConfidence: 2, 2026-10-23\n\nX [1].\n\n## Sources\n\n1. [a](https://e.com) 2026-10-23\n"},
        ("sources", "staging URL with no date"): {"member/t.staging.md": "X [1].\n\n## Sources\n\n1. [a](https://e.com)\n"},
        ("sources", "staging bare URL with no date"): {"member/t.staging.md": "X [1].\n\n## Sources\n\n1. https://e.com, retrieved soon\n"},
    }
    for (rule, name), tree in bad.items():
        code, out = run(rule, str(kb(tree)))
        cases.append((f"{rule} fires: {name}", code == 1 and out.strip() != ""))
    cases.append(("ownScoreWinsTest: heading score ok", score_problems("# T\nConfidence: 3, 2026-10-23\n\n## H\nConfidence: 1, 2026-10-23\n") == []))
    cases.append(("code fence is not a citation", source_problems("```\nx [1]\n```\n", "/tmp/a.md", "staging") == []))
    cases.append(("photoTest: suffix gives area", area(Path("d/IMG_1.source.jpeg")) == "source" and area(Path("d/IMG_1.jpeg")) == "none"))
    cases.append(("exemptTest", all(area(Path(p)) == "exempt" for p in ("CLAUDE.md", "d/CLAUDE.md", ".git/x", "plans/a.md"))))
    cases.append(("event folder dates its files", dated(Path("d/2026-10-01-visit/IMG_1.source.jpeg")) and not dated(Path("d/visit/IMG_1.source.jpeg"))))
    cases.append(("file mode", run("file", str(root / "member/colon/status.md"))[0] == 0 and run("file", str(kb(bad[("date", "sourceHasDate")]) / "member/scan.source.pdf"))[0] == 1))

    def g(tool, rel, **ti):
        ti["file_path"] = str(root / rel)
        code, out = run("guard", stdin=json.dumps({"tool_name": tool, "tool_input": ti}))
        return json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out.strip() else "allow"

    cases.append(("guard: exempt allowed", g("Write", "member/CLAUDE.md", content="x") == "allow"))
    cases.append(("guard: no area denied", g("Write", "member/x.jpeg", content="x") == "deny"))
    cases.append(("guard noDateTest: undated new source denied", g("Write", "member/x.source.md", content="x") == "deny"))
    cases.append(("guard: dated new source allowed", g("Write", "member/2026-01-01-x.source.md", content="x") == "allow"))
    cases.append(("guard oldSourceTest: old source asks", g("Write", "member/colon/2026-10-01-visit/note.source.md", content="y") == "ask"))
    cases.append(("guard stagingFree", g("Write", "member/colon/new.staging.md", content="anything") == "allow"))
    cases.append(("guard yesTest: complete page asks", g("Write", "member/colon/status.md", content=page) == "ask"))
    cases.append(("guard noScoreTest: no score denied, the user not asked", g("Write", "member/colon/new.md", content="# New\n") == "deny"))
    cases.append(("guard Edit that drops the score is denied", g("Edit", "member/colon/status.md", old_string="confidence: 3\n", new_string="") == "deny"))
    cases.append(("guard Edit that keeps the page whole asks", g("Edit", "member/colon/status.md", old_string="Aspirin", new_string="Aspirin 81 mg") == "ask"))
    cases.append(("guard MultiEdit applies each edit", g("MultiEdit", "member/colon/status.md", edits=[{"old_string": "Aspirin", "new_string": "A"}, {"old_string": "[1].", "new_string": "."}]) == "ask"))
    cases.append(("guard: outside a KB allowed", run("guard", stdin=json.dumps({"tool_name": "Write", "tool_input": {"file_path": str(harness / "a.md"), "content": ""}}))[1] == ""))

    def a(inp, env=None):
        os.environ.update(env or {})
        return run("after", stdin=json.dumps(inp))[1]

    out = a({"tool_name": "Write", "tool_input": {"file_path": str(root / "member/colon/trend.staging.md")}})
    cases.append(("after: staging write shows the confirmed headings (comparing)", "status.md" in out and "TODO(P1)" in out))
    (root / "member/colon/bad.md").write_text("# Bad\n")
    cases.append(("after: a failing file goes back to Claude", "no root score" in a({"tool_name": "Write", "tool_input": {"file_path": str(root / "member/colon/bad.md")}})))
    home = root.parent
    marker = Path(tempfile.mkdtemp()) / "m"
    marker.write_text("")
    os.utime(marker, ns=(1, 1))
    os.utime(root / "member/colon/status.md", ns=(1, 1))
    for p, _ in files(root):
        os.utime(p, ns=(1, 1), follow_symlinks=False)
    (root / "member/colon/status.md").write_text("# changed\n")
    out = a({"tool_name": "Bash", "tool_input": {"command": "sed -i ..."}}, {"KB_BASH_MARKER": str(marker), "KB_HOME": str(home)})
    cases.append(("bashTest: a Bash change is flagged", "status.md: a consolidated page changed outside the guard" in out and "trend.staging.md" not in out))

    failed = [n for n, ok in cases if not ok]
    for n, ok in cases:
        print(("ok   " if ok else "FAIL ") + n)
    print(f"{len(cases) - len(failed)} of {len(cases)} pass")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
