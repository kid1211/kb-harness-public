#!/usr/bin/env python3
"""The scans of plans/public-release. Standard library only.

  scan.py pii   <dir> <allow-list>   PII hits off the allow list
  scan.py names <dir> <deny-list>    deny terms, in file text and in paths
  scan.py list  <dir> <deny-list>    a copy of the deny list file in <dir>
  scan.py sample <kind>              a planted hit of a PII kind, made at run time
  scan.py owners <dir> <listed>      each plan, model and test a listed skill needs, off <listed>

Each hit prints as <file>:<line> <rule>, never the matched text. A path hit has
the line "path". Exit 0 clean, 1 on a hit, 2 when the deny list is missing or empty.
"""
import os
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


def scan_names(root, deny_path):
    hit = names_matcher(deny_terms(deny_path))
    hits = 0
    for rel, text in walk(root):
        if hit(fold(rel)):
            print(f"{rel}:path name")
            hits += 1
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
    the tests its Builds: line or 1-design.md names and the models its models import."""
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
    for m in sorted(missing):
        print(f"{m} not_listed: needed by a listed skill or library (R41)")
    return missing


def main(argv):
    if len(argv) == 3 and argv[1] == "sample":
        print(sample(argv[2]))
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
