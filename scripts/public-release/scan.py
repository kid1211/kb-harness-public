#!/usr/bin/env python3
"""The scans of plans/public-release. Standard library only.

  scan.py pii   <dir> <allow-list>   PII hits off the allow list
  scan.py names <dir> <deny-list>    deny terms, in file text and in paths. deny-allow/<type>.txt lists the files that may hold its terms
  scan.py list  <dir> <deny-list>    a copy of the deny list file in <dir>
  scan.py sample <kind>              a planted hit of a PII kind, made at run time
  scan.py owners <dir> <listed>      each plan, model and test a listed skill needs, off <listed>
  scan.py e2e   <dir>                each file of <dir> that no e2e test of tests/e2e/ names in its Covers (R56)
  scan.py e2e-for <dir> <changed>    the e2e tests whose Covers name a file of <changed>, one path per line

Each hit prints as <file>:<line> <rule>, never the matched text. A path hit has
the line "path". Exit 0 clean, 1 on a hit, 2 when the deny list is missing or empty.
"""
import os
import json
import re
import sys
import unicodedata

def luhn(text):
    """True when the digits of text pass the Luhn check, as card and SIN numbers do."""
    d = [int(c) for c in text if c.isdigit()]
    return sum(x if i % 2 == 0 else (x * 2 - 9 if x > 4 else x * 2) for i, x in enumerate(reversed(d))) % 10 == 0


# (rule, pattern, check). A match is a hit when its check passes and it is off the allow list.
PII = [
    ("email", re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"), None),
    ("phone", re.compile(r"(?<![\w.])(?:\+?1[ .-]?)?(?:\(\d{3}\)|\d{3})[ .-]\d{3}[ .-]\d{4}(?![\w.])"), None),
    # 10 digits with no separators: a North American area code and exchange start with 2 to 9.
    ("phone", re.compile(r"(?<![\w.])[2-9]\d{2}[2-9]\d{6}(?![\w.])"), None),
    ("account", re.compile(r"(?<![\w.])\d{12,19}(?![\w.])"), None),
    # Visa and Mastercard 4-4-4-4, Amex 4-6-5, with spaces or dashes.
    ("card", re.compile(r"(?<![\w.-])(?:4\d{3}|5[1-5]\d{2}|2[2-7]\d{2})([ -])\d{4}\1\d{4}\1\d{4}(?![\w.-])"), luhn),
    ("card", re.compile(r"(?<![\w.-])3[47]\d{2}([ -])\d{6}\1\d{5}(?![\w.-])"), luhn),
    # Four mask marks, then the last 4 digits. A bold year in Markdown has 2 stars, so it passes.
    ("masked card", re.compile(r"(?<![\w*\u2022\u25cf])[\u2022\u25cf*xX]{4}[ -]?\d{4}(?!\d)"), None),
    # A card brand, at most two words, then 4 digits. The brand word alone passes.
    ("card brand", re.compile(r"(?i)\b(?:amex|american express|visa|master ?card)\b(?:[ \t]+[a-z]+){0,2}?[ \t]+[x#*\u2022]*\d{4}(?!\d)"), None),
    # A SIN: 9 digits, 3-3-3 or bare, that pass the Luhn check. No SIN starts with 0 or 8.
    ("sin", re.compile(r"(?<![\w.-])[1-79]\d{2}([ -]?)\d{3}\1\d{3}(?![\w.-])"), luhn),
]


def sample(kind):
    """A planted hit of a kind, built at run time, so no file of the scans holds one."""
    def with_check(body):
        return next(body + c for c in "0123456789" if luhn(body + c))
    if kind == "account number":
        return with_check("4" + "1" * 14)
    if kind == "card":
        n = with_check("37" + "8" * 12)
        return f"{n[:4]} {n[4:10]} {n[10:]}"
    if kind == "masked card":
        return "\u2022" * 4 + " " + "4" + "2" * 3
    if kind == "card brand":
        return "Visa ending " + "5" * 4
    if kind == "sin":
        n = with_check("1" + "3" * 7)
        return f"{n[:3]} {n[3:6]} {n[6:]}"
    if kind == "bare phone":
        return "416" + "555" + "0" + "199"
    raise SystemExit(f"no sample of {kind}")
CJK = re.compile(r"[⺀-鿿가-힯豈-﫿]")


def fold(text):
    """NFKC, then case fold: a full-width or any-case form reads as the plain term."""
    return unicodedata.normalize("NFKC", text).casefold()


def walk(root):
    """Yield (relative path, text) for each file under root, .git left out.

    A symlink, to a file or a folder, yields its target text. A file with a NUL byte
    reads as UTF-16 if it starts with a BOM, else as Latin-1, so ASCII text in it is seen.
    """
    for d, dirs, files in os.walk(root):
        links = [x for x in dirs if os.path.islink(os.path.join(d, x))]
        dirs[:] = sorted(x for x in dirs if x != ".git" and x not in links)
        for f in sorted(files + links):
            p = os.path.join(d, f)
            rel = os.path.relpath(p, root)
            if os.path.islink(p):
                yield rel, os.readlink(p)
                continue
            with open(p, "rb") as fh:
                data = fh.read()
            if b"\0" not in data:
                yield rel, data.decode("utf-8", "replace")
            elif data[:2] in (b"\xff\xfe", b"\xfe\xff"):
                yield rel, data.decode("utf-16", "replace")
            else:
                yield rel, data.decode("latin-1")


def read_list(path):
    if not path or not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return [l.strip() for l in fh if l.strip() and not l.lstrip().startswith("#")]


def deny_terms(path):
    terms = [fold(t) for t in read_list(path)]
    if not terms:
        print(f"the deny list is missing or empty: {path}", file=sys.stderr)
        sys.exit(2)
    return terms


def names_matcher(terms):
    """CJK terms match as substrings. Each other term matches when no ASCII letter
    touches it, so for the term "ab", "ab_x", "ab2" and "ab的" match, and "abc" does not."""
    cjk = [t for t in terms if CJK.search(t)]
    words = sorted((t for t in terms if not CJK.search(t)), key=len, reverse=True)
    word_re = re.compile(r"(?<![a-z])(?:" + "|".join(map(re.escape, words)) + r")(?![a-z])") if words else None
    return lambda s: any(t in s for t in cjk) or bool(word_re and word_re.search(s))


def scan_pii(root, allow_path):
    allow = {a.casefold() for a in read_list(allow_path)}
    hits = 0
    for rel, text in walk(root):
        for n, line in enumerate(text.splitlines(), 1):
            for rule, rx, ok in PII:
                if any(m.group().casefold() not in allow and (ok is None or ok(m.group())) for m in rx.finditer(line)):
                    print(f"{rel}:{n} {rule}")
                    hits += 1
    return hits


# The allow lists of the name scan: one file per type, deny-allow/<type>.txt next to this script,
# such as cloud-storage.txt. Its "term: <term>" lines name the terms of the type, and each other line
# is a path where they may stand in the text. The file name holds no term, so a list of changed files
# names none. A term is never allowed in a path name. DENY_ALLOW names another folder, for the tests.
def allow_file(path):
    terms, paths = set(), []
    for line in read_list(path):
        if line.startswith("term:"):
            terms.add(fold(line[5:].strip()))
        else:
            paths.append(os.path.normpath(line))
    return terms, paths


def deny_allowed(folder):
    ok = {}
    if os.path.isdir(folder):
        for f in sorted(os.listdir(folder)):
            if f.endswith(".txt"):
                terms, paths = allow_file(os.path.join(folder, f))
                for rel in paths:
                    ok.setdefault(rel, set()).update(terms)
    return ok


def scan_names(root, deny_path):
    terms = deny_terms(deny_path)
    hit_path = names_matcher(terms)
    allow = deny_allowed(os.environ.get("DENY_ALLOW") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "deny-allow"))
    hits = 0
    for rel, text in walk(root):
        if hit_path(fold(rel)):
            print(f"{rel}:path name")
            hits += 1
        ok = allow.get(os.path.normpath(rel), set())
        if os.path.basename(os.path.dirname(rel)) == "deny-allow" and rel.endswith(".txt"):
            ok = ok | allow_file(os.path.join(root, rel))[0]  # an allow list names its own terms, no other
        hit = names_matcher([x for x in terms if x not in ok]) if ok else hit_path
        for n, line in enumerate(text.splitlines(), 1):
            if hit(fold(line)):
                print(f"{rel}:{n} name")
                hits += 1
    return hits


def find_list(root, deny_path):
    deny_terms(deny_path)
    with open(deny_path, "rb") as fh:
        want = fh.read()
    hits = 0
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x != ".git"]
        for f in files:
            p = os.path.join(d, f)
            if os.path.islink(p):
                continue
            with open(p, "rb") as fh:
                same = fh.read() == want
            if same or f == os.path.basename(deny_path):
                print(f"{os.path.relpath(p, root)}: the deny list file is in the copy")
                hits += 1
    return hits


def owners(root, listed_path):
    """R41: each plan level that builds a listed skill or library must be listed whole, with
    the tests its Builds: line or 1-design.md names and the models its models import. R53: and
    each other skill or library of the harness that a listed one names by path."""
    listed = set(read_list(listed_path))
    files = set()
    for d, _, names in os.walk(root):
        files.update(os.path.relpath(os.path.join(d, n), root) for n in names)
    under = lambda p: {f for f in files if f == p or f.startswith(p.rstrip("/") + "/")}
    parts = {"/".join(f.split("/")[:3]) + "/" for f in listed
             if re.match(r"\.claude/(skills|lib)/[^/]+/", f)}
    missing = set()
    for idx in sorted(f for f in files if f.startswith("plans/") and f.endswith("/0-index.md")):
        level = idx[: -len("0-index.md")]
        text = open(os.path.join(root, idx), encoding="utf-8").read()
        builds = " ".join(re.findall(r"^Builds:(.*)$", text, re.M))
        paths = re.findall(r"`([^`\s]+)`", builds)
        if not any(p.startswith(s) or s.startswith(p.rstrip("/") + "/") for p in paths for s in parts):
            continue
        need = under(level)
        design = os.path.join(root, level, "1-design.md")
        named = paths + (re.findall(r"`(?:bash |sh |python3 (?:-I )?)?([^`\s]+)", open(design, encoding="utf-8").read())
                         if os.path.exists(design) else [])
        for t in named:
            if t.startswith("tests/"):
                need |= under(t)
        for q in [f for f in need if f.endswith(".qnt")]:
            for imp in re.findall(r'from\s+"([^"]+)"', open(os.path.join(root, q), encoding="utf-8").read()):
                need |= under(os.path.normpath(os.path.join(os.path.dirname(q), imp + ".qnt")))
        missing |= need - listed
    # R53: a listed skill or library that names a path into another part of the harness needs it listed.
    for f in sorted(f for f in listed if any(f.startswith(s) for s in parts) and f in files):
        try:
            text = open(os.path.join(root, f), encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        for p in set(re.findall(r"\.claude/(?:skills|lib)/[A-Za-z0-9_.-]+/", text)) - parts:
            missing |= under(p) - listed
    for m in sorted(missing):
        print(f"{m} not_listed: needed by a listed skill or library (R41)")
    return missing


def scripts_of(hook):
    """The repo paths a hook command runs: each path after the "$(git rev-parse ...)" root."""
    return set(re.findall(r'\)"/([\w./-]+)', hook.get("command", "")))


def settings(src, listed_path):
    """R54: the hooks of settings.json whose scripts all go public, as JSON. Empty if none."""
    listed = set(read_list(listed_path))
    data = json.load(open(src, encoding="utf-8"))
    out = {}
    for event, groups in data.get("hooks", {}).items():
        kept = []
        for g in groups:
            hooks = [h for h in g.get("hooks", []) if scripts_of(h) and scripts_of(h) <= listed]
            if hooks:
                kept.append({**g, "hooks": hooks})
        if kept:
            out[event] = kept
    return json.dumps({"hooks": out}, indent=2) + "\n" if out else ""


# R56: these need no e2e test. Plans and tests are what the tests come from, the rest is no code.
E2E_FREE = ("plans/", "tests/", "changelogs/", ".github/")
E2E_FREE_FILES = {"README.md", "package.json", "package-lock.json", ".gitignore", "LICENSE"}


def e2e_covers(root):
    """{test path: [Covers paths]} of each tests/e2e/<part>/<test>.md. A path ending in / is a folder."""
    out = {}
    base = os.path.join(root, "tests", "e2e")
    for d, _, names in os.walk(base):
        for n in sorted(names):
            if n.endswith(".md"):
                p = os.path.join(d, n)
                m = re.search(r"^## Covers\n(.*?)(?=^## |\Z)", open(p, encoding="utf-8").read(), re.S | re.M)
                out[os.path.relpath(p, root)] = re.findall(r"`([^`\s]+)`", m.group(1)) if m else []
    return out


def covered(f, paths):
    return any(f == c or (c.endswith("/") and f.startswith(c)) for c in paths)


def e2e(root):
    """R56: each file of the copy, but plans, tests and docs, is named by the Covers of an e2e test."""
    allc = [c for cs in e2e_covers(root).values() for c in cs]
    miss = 0
    for d, dirs, names in os.walk(root):
        dirs[:] = [x for x in dirs if x != ".git"]
        for n in names:
            f = os.path.relpath(os.path.join(d, n), root)
            if (f.startswith(E2E_FREE) or f in E2E_FREE_FILES or "/tests/" in f
                    or ".test." in n or covered(f, allc)):
                continue
            print(f"{f}: no e2e test of tests/e2e/ covers it (no_e2e)")
            miss += 1
    return miss


def e2e_for(root, changed_path):
    """The e2e tests that cover a changed file, and each changed e2e test itself."""
    changed = read_list(changed_path)
    return sorted(t for t, cs in e2e_covers(root).items()
                  if t in changed or any(covered(f, cs) for f in changed))


def main(argv):
    if len(argv) == 3 and argv[1] == "e2e":
        return 1 if e2e(argv[2]) else 0
    if len(argv) == 4 and argv[1] == "e2e-for":
        print("\n".join(e2e_for(argv[2], argv[3])))
        return 0
    if len(argv) == 3 and argv[1] == "sample":
        print(sample(argv[2]))
        return 0
    if len(argv) == 4 and argv[1] == "settings":
        sys.stdout.write(settings(argv[2], argv[3]))
        return 0
    if len(argv) == 4 and argv[1] == "owners":
        return 1 if owners(argv[2], argv[3]) else 0
    if len(argv) != 4 or argv[1] not in ("pii", "names", "list"):
        print(__doc__, file=sys.stderr)
        return 2
    mode, root, lst = argv[1:]
    hits = {"pii": scan_pii, "names": scan_names, "list": find_list}[mode](root, lst)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
