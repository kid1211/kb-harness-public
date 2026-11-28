#!/usr/bin/env python3
"""Check Claude's prose against the writing rules in .claude/hooks/writing-rules.md,
and the Terms table of .claude/CLAUDE.md when that file is there.

Plan: plans/global/components/hooks/components/writing-check/.

Usage:
  writing-check.py post    PostToolUse hook: the text a .md edit adds (stdin JSON)
  writing-check.py stop    Stop hook: the last reply (stdin JSON)
  writing-check.py file F  check a file, print the result
  writing-check.py report [SESSION_ID]  the rules, thresholds, speed, and the log of a session and the week
  writing-check.py ste-setup  get the STE dictionary into ~/.claude/ste100/ (pip download, no install)
  writing-check.py --test

Each rule scores the share of sentences that pass. A rule under its threshold
fails. On a .md edit the hook returns {"decision": "block", "reason": ...}: feedback
only, the write is already done. On a reply the hook prints nothing, so no message
shows. Each check adds a line to LOG.
"""

import json
import pathlib
import re
import sys
import time

THRESHOLDS = {
    "length": 0.8,
    "bannedWords": 1.0,
    "checkedTerms": 1.0,
    "filler": 1.0,
    "weakWords": 0.8,
    "passive": 0.8,
    "repeatedWord": 1.0,
    "readability": 0.5,  # Flesch reading ease / 100 of the whole text. Replies on 2026-10-23 scored 74 to 100
    "paragraphs": 0.8,
    "semicolons": 1.0,
    "dashes": 0.8,
    "emoji": 0.8,  # emoji are fine, just not in every sentence
    "otherTerms": 0.5,  # 0.8 failed 4 of 6 good replies on 2026-10-23: "rule" and "section" are common
    "steWords": 0.2,  # 33 replies on 2026-10-23: median 0.45, and 0.2 fails the worst 6. Raise it as replies improve
    "aiTells": 1.0,
    "fullPaths": 1.0,  # replies only: each code or .md path starts with / or ~/
    "contractions": 0.0,  # casual only
    "rhythm": 0.0,  # casual only
    "person": 0.0,  # casual only
}
# Casual mode: no filler, no corporate words, no AI tells, and it sounds like a person.
# The STE rules are off.
CASUAL = {**{r: 0.0 for r in THRESHOLDS}, "bannedWords": 1.0, "checkedTerms": 1.0, "filler": 1.0,
          "repeatedWord": 1.0, "dashes": 0.8, "paragraphs": 0.8, "weakWords": 0.6, "readability": 0.6,
          "aiTells": 1.0, "contractions": 0.6, "rhythm": 0.35, "person": 1.0, "fullPaths": 1.0}
# Scores of the whole text, not a share of sentences, and what to do when one fails.
WHOLE = {
    "readability": "Use shorter words and sentences.",
    "contractions": "Write it as you would say it: don't, it's, I'll.",
    "rhythm": "Mix short sentences with longer ones.",
    "person": "Talk to the user: use I, you or we.",
}
CONTRACTED_RE = re.compile(r"\b\w+'(?:t|s|re|ll|ve|d|m)\b", re.I)
FULL_RE = re.compile(
    r"\b(?:(?:do|does|did|is|are|was|were|will|would|should|could|have|has|had) not|cannot"
    r"|it is|that is|there is|what is|I am|I will|I would|I have|you are|we are|they are"
    r"|you will|we will|let us)\b", re.I)
PERSON_RE = re.compile(r"\b(?:I|I'm|I'll|I've|I'd|me|my|you|you're|your|we|we're|let's|us|our)\b", re.I)
# The writing-mode buttons write {"reply": m, "docs": m}, m one of off, casual, pro. No file: pro.
MODE_FILE = pathlib.Path.home() / ".claude" / "writing-check-mode.json"
# The ASD-STE100 Issue 9 dictionary, from the PyPI package biz-dfch-asdste100vocab (AGPL-3.0),
# kept per machine, out of the repo. No file: steWords scores 1. `writing-check.py ste-setup` gets it.
STE_PACKAGE = "biz-dfch-asdste100vocab==0.8.1"
STE_FILE = pathlib.Path.home() / ".claude" / "ste100" / "asdste100_issue9_base.jsonl"
_ste = None


def ste_rejected():
    """{word: [approved alternatives]} for single words the dictionary only rejects."""
    global _ste
    # Parsing the 1.2 MB dictionary takes 11 ms. The map it gives, cached beside it, takes 1.
    cache = STE_FILE.with_suffix(".rejected.json")
    if _ste is None:
        try:
            if cache.stat().st_mtime >= STE_FILE.stat().st_mtime:
                _ste = json.loads(cache.read_text())
                return _ste
        except (OSError, ValueError):
            pass
        approved, rejected = set(), {}
        try:
            lines = STE_FILE.read_text().splitlines()
        except OSError:
            lines = []
        for line in lines:
            d = json.loads(line)
            name = d["name"].lower()
            if d["status"] == "approved":
                approved.add(name)
            elif d["status"] == "rejected" and " " not in name:
                rejected.setdefault(name, []).extend(a["name"].lower() for a in d["alternatives"])
        _ste = {w: alts for w, alts in rejected.items() if w not in approved}
        if lines:
            try:
                cache.write_text(json.dumps(_ste))
            except OSError:
                pass
    return _ste


def ste_hit(sentence):
    rejected = ste_rejected()
    for w in re.findall(r"[A-Za-z]+", sentence):
        if w.lower() in rejected:
            alts = rejected[w.lower()]
            return f"{w.lower()} -> {', '.join(alts[:3])}" if alts else w.lower()
    return None
STEP_LIMIT, OTHER_LIMIT = 20, 25
OFF_MARK = "<!-- writing-check: off -->"  # a file with this line is not checked
PARA_LIMIT = 3 # sentences in a plain paragraph, more should be a list
# The word tables. The Terms table stays in CLAUDE_MD, which the public release does not ship.
RULES = pathlib.Path(__file__).resolve().parent / "writing-rules.md"
CLAUDE_MD = pathlib.Path(__file__).resolve().parent.parent / "CLAUDE.md"
TERM_RULES = ("checkedTerms", "otherTerms")
LOG = pathlib.Path.home() / ".claude" / "writing-check.jsonl"

# A code or .md file path, with an optional :line. Not part of a URL or a longer path.
PATH_RE = re.compile(r"(?<![\w./~:-])((?:~?/)?[\w.@-]+(?:/[\w.@-]+)*\.(?:md|py|sh|js|mjs|ts|tsx|json|jsonl"
                     r"|qnt|html|css|adoc|toml|ya?ml))(?::\d+(?:-\d+)?)?(?![\w/-])")
FENCE_RE = re.compile(r"^\s*(```|~~~).*?^\s*\1[ \t]*$", re.M | re.S)
STEP_RE = re.compile(r"^\s*\d+[.)]\s+")
ITEM_RE = re.compile(r"^\s*(\d+[.)]|[-*+])\s+")
ABBREV_RE = re.compile(r"\b(e\.g|i\.e|etc|vs|cf)\.", re.I)
DASH_RE = re.compile(r"—|\s--\s")
# ponytail: a form of "be" plus a participle; misses "got made", flags "is tired"
PASSIVE_RE = re.compile(
    r"\b(am|is|are|was|were|be|been|being)\s+(\w+ly\s+)?"
    r"(\w+ed|built|done|made|given|shown|written|known|seen|found|sent|kept|taken|told"
    r"|run|set|put|read|left|held|brought|thought|bought|caught|taught|chosen|broken|spoken)\b", re.I)
REPEAT_RE = re.compile(r"\b([a-z]+)\s+\1\b", re.I)
EMOJI = "[\U0001F300-\U0001FAFF☀-➿\U0001F1E6-\U0001F1FF]️?"
EMOJI_RE = re.compile(EMOJI)
LEAD_EMOJI_RE = re.compile(rf"^(?:{EMOJI}\s*)+")  # a status emoji that starts a list item


def table(md, heading):
    """Rows of the first table after `heading`, as lists of cells."""
    section = md.split(heading, 1)[1]
    rows = []
    for line in section.splitlines():
        if line.startswith("#"):
            break
        if line.startswith("|"):
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
    return [r for r in rows[2:]]


def words(cell):
    """'rule (in a model), save / publish' -> ['rule', 'save', 'publish']."""
    cell = re.sub(r"\([^)]*\)", "", cell)
    return [w.strip() for w in re.split(r"[,/]", cell) if w.strip()]


def rules_text(with_terms=True):
    """The rules file, then the Terms table of .claude/CLAUDE.md if that file is there."""
    text = RULES.read_text()
    if with_terms:
        try:
            md = CLAUDE_MD.read_text()
        except OSError:
            return text
        if "### Terms" in md:
            text += "\n" + md[md.index("### Terms"):]
    return text


def word_lists(md):
    banned = [r[0] for r in table(md, "### Words not to use")]
    terms = table(md, "### Terms") if "### Terms" in md else []  # no .claude/CLAUDE.md: the term rules pass
    checked = [w for r in terms for w in words(r[2])]
    other = [w for r in terms for w in words(r[3])]
    filler = [r[0] for r in table(md, "### Phrases not to use")]
    weak = [r[0] for r in table(md, "### Weak words")]
    ai = [r[0] for r in table(md, "### AI tells")]
    return banned, checked, other, filler, weak, ai


def split(unit):
    return [s for s in re.split(r"(?<=[.!?])\s+", unit) if re.search(r"\w", s)]


def sentences(text):
    """(sentence, word limit) for each prose sentence."""
    return [(s, lim) for unit, lim, _ in units(text) for s in split(unit)]


def units(text):
    """(text, word limit, is a list item) for each paragraph and list item.
    Code blocks, tables and headings are dropped. A code span or a quote
    counts as one word."""
    prose = FENCE_RE.sub("", text).replace("’", "'")
    prose = re.sub(r"`[^`\n]*`", "X", prose)
    prose = re.sub(r"\"[^\"\n]*\"|“[^”\n]*”", "X", prose)  # a quote mentions words, it does not use them
    prose = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", prose)
    prose = re.sub(r"<!--.*?-->", "", prose, flags=re.S)
    prose = re.sub(r"<[a-z]+:[^|>\s]*\|([^>]*)>", r"\1", prose)  # Slack link <url|text>
    prose = re.sub(r"</?[A-Za-z][^>]*>", "", prose)  # HTML tags, Slack <url>
    prose = re.sub(r"\*\*|__|~~", "", prose)
    prose = re.sub(r"(?<![\w*_~])[*_~](?=\S)([^*_~\n]+?)(?<=\S)[*_~](?![\w*_~])", r"\1", prose)  # *x* _x_ ~x~
    prose = ABBREV_RE.sub(lambda m: m.group(1), prose)
    out, cur, limit, item = [], [], OTHER_LIMIT, False
    for line in prose.splitlines() + [""]:
        s = line.strip()
        if not s or s.startswith("#") or "|" in s or ITEM_RE.match(line):  # a pipe outside code is a table row
            if cur:
                out.append((" ".join(cur), limit, item))
            cur, limit, item = [], OTHER_LIMIT, False
            if ITEM_RE.match(line):
                limit = STEP_LIMIT if STEP_RE.match(line) else OTHER_LIMIT
                cur, item = [LEAD_EMOJI_RE.sub("", ITEM_RE.sub("", line).strip())], True
            continue
        cur.append(s)
    return out


def hit(sentence, terms):
    for t in terms:
        if re.search(r"(?<!\w)" + re.escape(t) + r"s?(?!\w)", sentence, re.I):
            return t
    return None


def short_paths(text):
    """(paths found, the ones not from / or ~/) outside code blocks. Node.js and the like are names."""
    found = [m.group(1) for m in PATH_RE.finditer(FENCE_RE.sub("", text))
             if "/" in m.group(1) or not re.match(r"[A-Z][A-Za-z0-9]*\.js$", m.group(1))]
    return found, [f for f in found if not f.startswith(("/", "~/"))]


def check(text, md, reply=False):
    """{rule: (score, [(sentence, why), ...])} over the prose of `text`."""
    banned, checked, other, filler, weak, ai = word_lists(md)
    sents = sentences(text)
    tests = {
        "aiTells": lambda s, lim: hit(s, ai),
        "filler": lambda s, lim: hit(s, filler),
        "weakWords": lambda s, lim: hit(s, weak),
        "passive": lambda s, lim: (m := PASSIVE_RE.search(s)) and m.group(0),
        "repeatedWord": lambda s, lim: (m := REPEAT_RE.search(s)) and m.group(0),
        "length": lambda s, lim: (n := len([w for w in s.split() if re.search(r"\w", w)])) > lim
        and f"{n} words, limit {lim}",
        "bannedWords": lambda s, lim: hit(s, banned),
        "checkedTerms": lambda s, lim: hit(s, checked),
        "semicolons": lambda s, lim: ";" in s and "semicolon",
        "dashes": lambda s, lim: DASH_RE.search(s) and "dash",
        "emoji": lambda s, lim: (m := EMOJI_RE.search(s)) and m.group(0),
        "otherTerms": lambda s, lim: hit(s, other),
        "steWords": lambda s, lim: ste_hit(s),
    }
    result = {}
    for rule, test in tests.items():
        bad = [(s, why) for s, lim in sents if (why := test(s, lim))]
        score = 1 - len(bad) / len(sents) if sents else 1.0
        result[rule] = (score, bad)
    paras = [u for u, _, item in units(text) if not item]
    bad = [(p, f"{n} sentences, make it a list") for p in paras if (n := len(split(p))) > PARA_LIMIT]
    result["paragraphs"] = (1 - len(bad) / len(paras) if paras else 1.0, bad)
    result["readability"] = (flesch([s for s, _ in sents]), [])
    result["contractions"] = (contracted(sents), [])
    result["rhythm"] = (rhythm(sents), [])
    words = sum(len(s.split()) for s, _ in sents)
    result["person"] = (1.0 if words < 30 or any(PERSON_RE.search(s) for s, _ in sents) else 0.0, [])
    found, short = short_paths(text) if reply else ([], [])
    result["fullPaths"] = (1 - len(short) / len(found) if found else 1.0,
                           [(f, "write it in full, from ~/") for f in short])
    return result


def contracted(sents):
    """Share of contractible pairs written short ("don't" over "do not"). No pair: 1."""
    text = " ".join(s for s, _ in sents)
    short, full = len(CONTRACTED_RE.findall(text)), len(FULL_RE.findall(text))
    return short / (short + full) if short + full else 1.0


def rhythm(sents):
    """Spread of sentence lengths, standard deviation / mean, capped at 1. Under 5 sentences: 1."""
    ns = [len(s.split()) for s, _ in sents]
    if len(ns) < 5:
        return 1.0
    mean = sum(ns) / len(ns)
    return min(1.0, (sum((n - mean) ** 2 for n in ns) / len(ns)) ** 0.5 / mean)


def syllables(word):
    # ponytail: vowel-group count, off by one on some words; fine for an average
    n = len(re.findall(r"[aeiouy]+", word.lower()))
    return max(1, n - (word.lower().endswith("e") and n > 1))


def flesch(sents):
    """Flesch reading ease on a 0 to 1 scale (score / 100). Higher is easier."""
    ws = [w for s in sents for w in re.findall(r"[A-Za-z]+", s)]
    if len(ws) < 30:  # too short to score
        return 1.0
    score = 206.835 - 1.015 * len(ws) / len(sents) - 84.6 * sum(map(syllables, ws)) / len(ws)
    return max(0.0, min(score, 100.0)) / 100


def mode(kind):
    """off, casual or pro for 'reply' or 'docs'."""
    try:
        m = json.loads(MODE_FILE.read_text()).get(kind, "pro")
    except (OSError, ValueError):
        return "pro"
    return m if m in ("off", "casual", "pro") else "pro"


def report(result, thresholds=THRESHOLDS):
    """The feedback for Claude, or None if every rule passes."""
    lines = []
    for rule, (score, bad) in result.items():
        if score < thresholds[rule]:
            if rule in WHOLE:
                lines.append(f"FAIL {rule}: {score:.2f}, needs {thresholds[rule]:.2f}. {WHOLE[rule]}")
                continue
            what = {"paragraphs": "paragraphs", "fullPaths": "paths"}.get(rule, "sentences")
            lines.append(f"FAIL {rule}: {score:.0%} of {what} pass, needs {thresholds[rule]:.0%}")
            for s, why in bad[:3]:
                lines.append(f'  - "{s[:70]}..." ({why})')
    if not lines:
        return None
    failed = [l.split(":")[0][5:] for l in lines if l.startswith("FAIL ")]
    where = ([f".claude/hooks/{RULES.name}"] if any(r not in TERM_RULES for r in failed) else []) + \
            (["the Terms table of .claude/CLAUDE.md"] if any(r in TERM_RULES for r in failed) else [])
    return "\n".join([f"writing-check: the text breaks the writing rules in {' and '.join(where)}."] + lines)


def ste_counts(text):
    """{rejected STE word: times used} over the prose of `text`."""
    rejected, counts = ste_rejected(), {}
    for s, _ in sentences(text):
        for w in re.findall(r"[A-Za-z]+", s):
            if w.lower() in rejected:
                counts[w.lower()] = counts.get(w.lower(), 0) + 1
    return counts


def log(kind, where, result, session="", ste=None):
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as f:
            f.write(json.dumps({"time": time.strftime("%Y-%m-%dT%H:%M:%S"), "kind": kind,
                                "where": where, "session": session,
                                "scores": {r: round(s, 3) for r, (s, _) in result.items()},
                                "ste": ste or {}}) + "\n")
    except OSError:
        pass


def added_text(tool_input):
    if "content" in tool_input:
        return tool_input["content"]
    if "edits" in tool_input:
        return "\n\n".join(e.get("new_string", "") for e in tool_input["edits"])
    return tool_input.get("new_string", "")


def last_reply(transcript_path):
    """Text of the assistant entries after the last user entry."""
    texts = []
    try:
        lines = pathlib.Path(transcript_path).read_text().splitlines()
    except OSError:
        return ""
    for line in reversed(lines):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("isSidechain"):
            continue
        if d.get("type") == "user":
            break
        if d.get("type") == "assistant":
            content = d.get("message", {}).get("content", [])
            texts += [c.get("text", "") for c in reversed(content)
                      if isinstance(c, dict) and c.get("type") == "text"]
    return "\n\n".join(reversed(texts))


# Chart notes (chart-suggest R5, R7): a docs edit whose tables or words show a chart signal
# gets a note that names a form. Advice, not a failure. The forms and reasons come from the
# signal table of the chart catalog page in the personal KB.
CHART_CATALOG = pathlib.Path.home() / "second-brain/personal/claude-research/staging/2026-10-25-chart-catalog/chart-catalog.staging.md"
CHART_MISSING = pathlib.Path.home() / ".claude" / "writing-check-chart-missing"  # logged once, removed when the page is back
DATE_CELL = re.compile(r"\b\d{4}-\d{2}(?:-\d{2})?\b|\b\d{1,2}/\d{1,2}/\d{2,4}\b|\b\d{1,2} (?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.? \d{4}\b|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]* \d{4}\b", re.I)
NUM_CELL = re.compile(r"^[~≈+−-]?\s*(?:about\s+)?[$€£]?\s*-?\d[\d,]*(?:\.\d+)?\s*(?:%|k|m|bn)?\b", re.I)
MONEY_HEAD = re.compile(r"%|\$|rate|fee|price|cost|paid|amount|payout|return|yield|spend|balance|from .*high", re.I)
LIMIT_HEAD = re.compile(r"\b(?:total|limit|target|budget|minimum|maximum|max|cap)\b", re.I)
CHART_WORDS = {
    # a share needs two or more percentages in the sentence, so "keeps 15% of dividends" is no note
    "share": re.compile(r"(?=.*\b(?:share of|breakdown|split)\b)(?=(?:.*?\d%){2})", re.I),
    # from 5.1% to 4.2%, from $40 to $55. Not from 2027 to 2031: years are not a change in value
    "before-after": re.compile(r"\bbefore and after\b(?=(?:.*?\d){2})|\bfrom (?!(?:19|20)\d\d\b)[$€£]?\d[\d,.]*%? to [$€£]?\d", re.I),
    "chance": re.compile(r"\bout of \d|\bin 100\b|\bchance\b|\brisk\b", re.I),
}
# a doc that names table-like data it does not hold (chart-suggest R9): no number needed
DATA_MENTION = re.compile(r"\b(?:csv|tsv|xlsx?|spreadsheets?|excel|(?<!cheat )sheets?)\b", re.I)


def chart_signals(path=None):
    """{signal: (form, why)} from the catalog's signal table, or None if the page is missing."""
    try:
        text = (path or CHART_CATALOG).read_text()
    except OSError:
        return None
    rows = {}
    for cells in table(text, "Signal table"):
        if len(cells) >= 5:
            rows[cells[0].strip("` ")] = (cells[3], cells[4])
    return rows


def md_tables(text):
    """[(header, rows)] for each markdown table in text."""
    out, block = [], []
    for line in text.splitlines() + [""]:
        if line.lstrip().startswith("|"):
            block.append([c.strip() for c in line.strip().strip("|").split("|")])
        else:
            if len(block) >= 3 and set("".join(block[1])) <= set("-: "):
                out.append((block[0], block[2:]))
            block = []
    return out


DATA_LINK = re.compile(r"\]\(\s*(?:<([^>]+\.(?:csv|tsv|xlsx))>|([^)\s]+\.(?:csv|tsv|xlsx)))\s*\)", re.I)  # [x](a.csv), [x](<a b.csv>)
DATA_BLOCK = re.compile(r"^```(csv|tsv)\s*\n(.*?)^```", re.S | re.M | re.I)
SF_DATALESS = 0x40000000  # macOS: the file is in iCloud only, and a read would download it
DATA_MAX_BYTES, DATA_MAX_ROWS = 5_000_000, 500


def delimited(text, sep):
    """(header, rows) of csv or tsv text, at most DATA_MAX_ROWS rows."""
    import csv
    rows = [r for _, r in zip(range(DATA_MAX_ROWS + 1), csv.reader(text.splitlines(), delimiter=sep)) if r]
    return (rows[0], rows[1:]) if len(rows) > 1 else None


def xlsx_table(path):
    """(header, rows) of the first sheet of an .xlsx file, with only the stdlib."""
    import zipfile
    import xml.etree.ElementTree as ET
    m = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        shared = []
        if "xl/sharedStrings.xml" in names:
            shared = ["".join(t.text or "" for t in si.iter(m + "t"))
                      for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall(m + "si")]
        sheets = sorted(n for n in names if n.startswith("xl/worksheets/sheet"))
        if not sheets:
            return None
        rows = []
        for row in ET.fromstring(z.read(sheets[0])).iter(m + "row"):
            cells = {}
            for c in row.findall(m + "c"):
                col = re.sub(r"\d", "", c.get("r", "")) or str(len(cells))
                v, t = c.find(m + "v"), c.find(m + "is/" + m + "t")
                val = t.text if t is not None else (v.text if v is not None else "")
                if c.get("t") == "s" and (val or "").isdigit() and int(val) < len(shared):
                    val = shared[int(val)]
                cells[col] = val or ""
            rows.append([cells[k] for k in sorted(cells, key=lambda k: (len(k), k))])
            if len(rows) > DATA_MAX_ROWS:
                break
    return (rows[0], rows[1:]) if len(rows) > 1 else None


def linked_table(doc, target):
    """(header, rows) of a data file a doc links to, or None if it is missing, large or in iCloud only."""
    if "://" in target:
        return None
    f = (pathlib.Path(doc).parent / target).resolve()
    try:
        st = f.stat()
        if getattr(st, "st_flags", 0) & SF_DATALESS or st.st_size > DATA_MAX_BYTES:
            return None
        if f.suffix.lower() == ".xlsx":
            return xlsx_table(f)
        return delimited(f.read_text(errors="replace"), "\t" if f.suffix.lower() == ".tsv" else ",")
    except Exception:  # a broken file gives no note, never a failed hook
        return None


def data_tables(text, doc=""):
    """[(label, header, rows)] for every markdown table, csv or tsv block, and linked data file."""
    out = [("table", h, r) for h, r in md_tables(text)]
    for kind, body in DATA_BLOCK.findall(text):
        t = delimited(body, "\t" if kind.lower() == "tsv" else ",")
        if t:
            out.append((f"{kind.lower()} block", *t))
    from urllib.parse import unquote
    for target in (unquote(a or b) for a, b in DATA_LINK.findall(text)) if doc else []:
        t = linked_table(doc, target)
        if t:
            out.append((f"file {target}", *t))
    return out


def table_signal(header, rows):
    """The chart signal a table shows, or None."""
    n = len(rows)
    cols = list(zip(*[r + [""] * (len(header) - len(r)) for r in rows])) if rows else []

    def share(col, rx):
        return sum(bool(rx.search(c)) for c in col) / max(len(col), 1)
    nums = [i for i, c in enumerate(cols) if share(c, NUM_CELL) >= 0.6]
    dates = [i for i, c in enumerate(cols) if share(c, DATE_CELL) >= 0.6]
    money = [i for i in nums if i < len(header) and (MONEY_HEAD.search(header[i]) or share(cols[i], re.compile(r"[%$€£]")) >= 0.6)]
    limits = [i for i, h in enumerate(header) if LIMIT_HEAD.search(h)]
    if dates and set(nums) - set(dates) and n >= 5:
        return "date-trend"
    if limits and set(nums) - set(limits):
        return "limit"
    if n >= 10 and len(money) >= 3:
        return "compare-grid"
    if n >= 10 and money:
        return "compare-many"
    if n == 1 and 2 <= len(nums) <= 6 and len(header) - len(nums) <= 1:
        return "one-row"
    return None


def chart_notes(text, signals, doc=""):
    """One line per chart signal in the added text."""
    notes, seen = [], set()
    for label, header, rows in data_tables(text, doc):
        sig = table_signal(header, rows)
        if sig in signals and sig not in seen:
            seen.add(sig)
            form, why = signals[sig]
            notes.append(f"- {label} \"{' | '.join(header)[:50]}\": {sig} -> {form}, because {why}")
    prose = re.sub(r"```.*?```", "", text, flags=re.S)
    for sent, _ in sentences("\n".join(l for l in prose.splitlines() if not l.lstrip().startswith("|"))):
        if not re.search(r"\d", sent):
            continue
        for sig, rx in CHART_WORDS.items():
            if sig in signals and sig not in seen and rx.search(sent):
                seen.add(sig)
                form, why = signals[sig]
                notes.append(f"- \"{sent[:50]}\": {sig} -> {form}, because {why}")
                break
    if "data-mention" in signals and not notes and DATA_MENTION.search(prose):
        form, why = signals["data-mention"]
        notes.append(f"- \"{DATA_MENTION.search(prose)[0]}\": data-mention -> {form}, because {why}")
    return notes[:3]  # one note per signal, at most 3, so a long page does not flood Claude


def hook(event, data, md=None):
    """The hook's stdout for one event, or None. With no `md`, it reads the rules after the skips."""
    if event == "post":
        ti = data.get("tool_input", {})
        path = ti.get("file_path", "")
        if not path.endswith(".md") or "/raw-deep-research/" in path:
            return None
        text, kind = added_text(ti), "file"
        try:
            if OFF_MARK in pathlib.Path(path).read_text():
                return None
        except OSError:
            pass
    else:
        if data.get("stop_hook_active"):
            return None
        text = data.get("last_assistant_message") or last_reply(data.get("transcript_path", ""))
        path, kind = "", "reply"
    m = mode("reply" if kind == "reply" else "docs")
    if m == "off":
        return None
    if md is None:
        md = rules_text()
    result = check(text, md, reply=kind == "reply")
    log(f"{kind}/{m}", path, result, data.get("session_id", ""), ste_counts(text))
    msg = report(result, CASUAL if m == "casual" else THRESHOLDS)
    note = ""
    if kind == "file" and CHART_CATALOG.resolve() != pathlib.Path(path).resolve():
        signals = chart_signals()
        if signals is None:
            if not CHART_MISSING.exists():  # once, not on every edit
                log("chart/missing", str(CHART_CATALOG), {}, data.get("session_id", ""))
                try:
                    CHART_MISSING.touch()
                except OSError:
                    pass
        else:
            CHART_MISSING.unlink(missing_ok=True)
            notes = chart_notes(text, signals, path)
            if notes:
                log("chart/note", path, {}, data.get("session_id", ""))
                note = ("Chart note (advice, not a failure): this content may read better as a chart. "
                        f"Forms and scores: {CHART_CATALOG}. Draw one only if it helps the reader.\n" + "\n".join(notes))
    if not msg:
        if note:
            return json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": note}})
        return None
    if note:
        msg += "\n" + note
    if kind == "reply":
        msg += "\nWrite the reply again, fixed. Do not mention this check."
    else:
        msg += f"\nFix the text you added to {path}."
    return json.dumps({"decision": "block", "reason": msg})


def test():
    import tempfile  # 14 ms to import, so only the tests pay for it
    md = rules_text()
    if "### Terms" not in md:  # a clone with no .claude/CLAUDE.md: the term tests use this table
        md += ("\n### Terms\n\n| Term | Means | Never call it | Do not call it, in this sense |\n|---|---|---|---|\n"
               "| KB | a knowledge-base repo | vault, wiki | |\n| skill | a folder with a SKILL.md | plugin | command, tool |\n"
               "| model | a .qnt file | | spec |\n| invariant | a val | | property, rule |\n| commit / push | a commit / a push | | save, publish |\n")
    fails = []

    def expect(name, cond):
        if not cond:
            fails.append(name)

    banned, checked, other, filler, weak, ai = word_lists(md)
    expect("reads ai tells", "delve" in ai)
    found, short = short_paths("See `mac-setup/a.md`, ~/x/b.py, /c/d.sh:12, CLAUDE.md and [e.md](/f/e.md). "
                               "Node.js, https://x.com/g.md.\n```\nrun h.sh\n```")
    expect("short paths", short == ["mac-setup/a.md", "CLAUDE.md", "e.md"] and len(found) == 6)
    expect("short path fails a reply", "fullPaths" in (report(check("Edit `a/b.md`.", md, reply=True)) or ""))
    expect("short path fails in casual",
           "fullPaths" in (report(check("Edit `a/b.md`.", md, reply=True), CASUAL) or ""))
    expect("full path passes", check("Edit `~/a/b.md`.", md, reply=True)["fullPaths"][0] == 1)
    expect("a file edit keeps its paths", check("Edit `a/b.md`.", md)["fullPaths"][0] == 1)
    expect("ai tell fails in pro", "aiTells" in (report(check("Let's delve into it.", md)) or ""))
    expect("ai tell fails in casual", "aiTells" in (report(check("Let's delve into it.", md), CASUAL) or ""))
    stiff = ("I do not know. It is not done. We will not ship it today because the tests do not pass "
             "and the hook is not ready for you yet.")
    expect("few contractions fail in casual", "contractions" in (report(check(stiff, md), CASUAL) or ""))
    expect("few contractions fine in pro", "contractions" not in (report(check(stiff, md)) or ""))
    expect("contractions pass", contracted([("I don't know. It's done. We won't ship.", 25)]) == 1.0)
    flat = " ".join(["The hook reads the file and checks it now."] * 6)
    expect("even rhythm fails in casual", "rhythm" in (report(check(flat, md), CASUAL) or ""))
    mixed = ("Done. The hook reads every reply, scores it, and writes a line to the log. "
             "Fast. It never calls a model, so a check costs nothing. Nice. That's it for now.")
    expect("mixed rhythm passes", rhythm(sentences(mixed)) >= CASUAL["rhythm"])
    impersonal = ("The hook reads the reply. The script checks each rule in turn. The log keeps "
                  "the scores. The thresholds sit at the top of the script. A press of a button changes the mode.")
    expect("no person fails in casual", "person" in (report(check(impersonal, md), CASUAL) or ""))
    expect("person passes", check("You can press it. " + impersonal, md)["person"][0] == 1.0)
    expect("reads filler phrases", "it's worth noting" in filler and "due to the fact that" in filler)
    expect("reads weak words", "very" in weak)
    expect("wordy phrase fails", check("Due to the fact that it runs, stop.", md)["filler"][0] < 1)
    expect("weak word scores", check("It is very fast.", md)["weakWords"][0] < 1)
    expect("passive scores", check("The file was removed by Claude.", md)["passive"][0] < 1)
    expect("active passes passive", check("Claude removed the file.", md)["passive"][0] == 1)
    jargon = ("The implementation necessitates comprehensive consideration of organizational "
              "infrastructure requirements. Configuration modifications substantially complicate "
              "operational responsibilities. ") * 3
    expect("jargon fails readability", "readability" in (report(check(jargon, md)) or ""))
    expect("short text not scored", check("Utilization.", md)["readability"][0] == 1.0)
    expect("repeated word fails", check("Run the the check.", md)["repeatedWord"][0] < 1)
    expect("filler fails", check("It's worth noting that it runs.", md)["filler"][0] < 1)
    expect("let me know is fine", report(check("Let me know.", md)) is None)
    long_para = "It runs. It checks. It logs. It stops."
    expect("4-sentence paragraph fails", "paragraphs" in (report(check(long_para, md)) or ""))
    expect("4-item list passes", report(check("- It runs.\n- It checks.\n- It logs.\n- It stops.", md)) is None)
    expect("3-sentence paragraph passes", report(check("It runs. It checks. It logs.", md)) is None)
    expect("reads banned words", "utilize" in banned and "seamless" in banned)
    expect("reads checked terms", "vault" in checked and "plugin" in checked)
    expect("reads other terms", "spec" in other and "rule" in other and "publish" in other)
    expect("checked and other apart", not set(checked) & set(other))

    good = "The hook checks each reply. If a check fails, Claude fixes the text."
    expect("good text passes", report(check(good, md)) is None)

    bad = ("We should utilize the hook; it will basically facilitate a seamless check of "
           "every single sentence that Claude writes in every reply and every file it makes.")
    r = check(bad, md)
    expect("banned word fails", r["bannedWords"][0] < 1)
    expect("long sentence fails", r["length"][0] < 0.8)
    expect("vault fails", check("Put it in the vault.", md)["checkedTerms"][0] < 1)
    expect("plural plugins fails", check("Add two plugins.", md)["checkedTerms"][0] < 1)
    expect("semicolon fails", check("It works; mostly.", md)["semicolons"][0] < 1)
    expect("dash fails", check("It works — mostly.", md)["dashes"][0] < 1)
    expect("double dash fails", check("It works -- mostly.", md)["dashes"][0] < 1)

    # 4 of 5 sentences pass: exactly at the 80% threshold, so the rule passes.
    four = "- Run it — now.\n- Read it.\n- Fix it.\n- Push it.\n- Commit it."
    expect("80% passes", check(four, md)["dashes"][0] == 0.8 and report(check(four, md)) is None)
    three = "- Run it — now.\n- Use it — now.\n- Fix it.\n- Push it.\n- Commit it."
    expect("60% fails", "dashes" in (report(check(three, md)) or ""))
    expect("a quote is a mention", report(check('The table lists "vault" and "utilize".', md)) is None)

    exempt = "Fine.\n\n```\nutilize; leverage — vault\n```\n\n| utilize | vault |\n\nUse `a — b; c`."
    expect("code, tables, spans exempt", report(check(exempt, md)) is None)
    expect("emoji fails in pro", "emoji" in (report(check("It works 🎉.", md)) or ""))
    expect("status emoji on an item is fine", report(check("- 🎯 **R1. It runs:** it checks.\n- ✅ It stops.", md)) is None)
    expect("emoji in a table is fine", report(check("| ✅ | done |\n\nIt runs.", md)) is None)
    expect("emoji fine in casual", report(check("It works 🎉.", md), CASUAL) is None)
    expect("bold lead-in splits", len(sentences("**Where it lives.** The plan holds it.")) == 2)
    expect("italic and strike stripped", len(sentences("_Done._ ~Old.~ *New.* It runs.")) == 4)
    expect("list with * still a list", report(check("* It runs.\n* It checks.\n* It logs.\n* It stops.", md)) is None)
    expect("html comment exempt", report(check("<!-- writing-check: off -->\n\nIt runs.", md)) is None)
    slack = "See <https://x.io/a|the vault page>. It runs."
    expect("slack link text checked", check(slack, md)["checkedTerms"][0] < 1)
    expect("slack link not a table", len(sentences(slack)) == 2)
    no_pipes ="Rule | Threshold\n--- | ---\nutilize; x | 80%\n\n---\n\nThe check passes."
    expect("table without edge pipes, and a rule line, exempt", report(check(no_pipes, md)) is None)
    expect("e.g. is not a full stop", len(sentences("Use a hook, e.g. a Stop hook.")) == 1)

    # Negative control: the threshold is what lets a bad text through.
    expect("negative control", report(check("Put it in the vault.", md)) is not None)

    global MODE_FILE, STE_FILE, _ste, LOG, CHART_CATALOG
    ste_saved, STE_FILE, _ste = STE_FILE, pathlib.Path(tempfile.mkdtemp()) / "ste.jsonl", None
    STE_FILE.write_text("\n".join(json.dumps(e) for e in [
        {"name": "use", "status": "approved", "alternatives": []},
        {"name": "utilize", "status": "rejected", "alternatives": [{"name": "USE"}]},
        {"name": "close", "status": "approved", "alternatives": []},
        {"name": "close", "status": "rejected", "alternatives": [{"name": "NEAR"}]},
        {"name": "aft of", "status": "rejected", "alternatives": []}]))
    r = check("We utilize it. Close it. Use it. Stop it.", md)["steWords"]
    expect("ste scores rejected words", r[0] == 0.75 and r[1][0][1] == "utilize -> use")
    expect("ste fails in pro", "steWords" in (report(check("We utilize it.", md)) or ""))
    expect("ste off in casual", "steWords" not in (report(check("We utilize it.", md), CASUAL) or ""))
    STE_FILE, _ste = pathlib.Path("/nonexistent/ste.jsonl"), None
    expect("no ste file scores 1", check("We utilize it.", md)["steWords"][0] == 1.0)
    STE_FILE, _ste = ste_saved, None

    saved, MODE_FILE = MODE_FILE, pathlib.Path(tempfile.mkdtemp()) / "mode.json"
    stop = {"last_assistant_message": "We leverage it; done."}
    expect("no mode file is pro", mode("reply") == "pro" and hook("stop", stop, md))
    MODE_FILE.write_text('{"reply": "off", "docs": "pro"}')
    expect("off skips the reply", hook("stop", stop, md) is None)
    expect("docs still on", hook("post", {"tool_input": {"file_path": "a.md", "content": bad}}, md))
    MODE_FILE.write_text('{"reply": "casual"}')
    expect("casual allows semicolons", hook("stop", {"last_assistant_message": "It runs; it works."}, md) is None)
    expect("casual still bans leverage", hook("stop", stop, md))
    MODE_FILE.write_text("not json")
    expect("bad file is pro", mode("reply") == "pro")
    MODE_FILE = saved

    text = overview(md)
    expect("report lists every rule", all(r in text for r in THRESHOLDS) and set(RULE_TEXT) == set(THRESHOLDS))
    expect("report shows speed", "10000 words:" in text)
    log_saved, LOG = LOG, pathlib.Path(tempfile.mkdtemp()) / "log.jsonl"
    hook("stop", {"session_id": "s1", "last_assistant_message": "We utilize it."}, md)
    hook("stop", {"session_id": "s2", "last_assistant_message": "It runs."}, md)
    text = overview(md, session="s1")
    expect("report has the session", "This session (s1): 1 checks" in text and "last 7 days, 2 checks" in text)
    expect("report has fails per rule", "bannedWords" in text and "1/2 50%" in text)
    expect("report puts passes when after a tab", "\tno ;" in text)
    LOG = log_saved

    expect("post skips raw dumps", hook("post", {"tool_input": {
        "file_path": "/kb/x/raw-deep-research/a.md", "content": bad}}, md) is None)
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
        f.write(OFF_MARK + "\n" + bad)
    expect("post skips a file marked off", hook("post", {"tool_input": {"file_path": f.name, "content": bad}}, md) is None)
    pathlib.Path(f.name).unlink()
    expect("post skips non-md", hook("post", {"tool_input": {"file_path": "a.py", "content": bad}}, md) is None)
    out = hook("post", {"tool_input": {"file_path": "a.md", "old_string": "x", "new_string": bad}}, md)
    expect("post blocks a bad edit", out and json.loads(out)["decision"] == "block")
    expect("stop once only", hook("stop", {"stop_hook_active": True, "last_assistant_message": bad}, md) is None)

    with tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False) as f:
        for e in [{"type": "assistant", "message": {"content": [{"type": "text", "text": "Old reply."}]}},
                  {"type": "user", "message": {"content": [{"type": "tool_result"}]}},
                  {"type": "assistant", "message": {"content": [{"type": "text", "text": "First part."}]}},
                  {"type": "assistant", "message": {"content": [{"type": "text", "text": "Second part."}]}}]:
            f.write(json.dumps(e) + "\n")
    expect("last reply from transcript", last_reply(f.name) == "First part.\n\nSecond part.")
    pathlib.Path(f.name).unlink()

    sig = {"date-trend": ("Line", "trend"), "compare-many": ("Bar", "size"), "compare-grid": ("Heat map", "grid"),
           "limit": ("Meter", "limit"), "one-row": ("KPI row", "few"), "share": ("Stacked bar", "parts"),
           "before-after": ("Dumbbell", "change"), "chance": ("Stat tile", "chance")}
    trend = "| Date | Paid |\n|---|---|\n" + "".join(f"| 2026-0{i}-01 | ${i}0 |\n" for i in range(1, 7))
    expect("chart: date trend", "date-trend -> Line" in "".join(chart_notes(trend, sig)))
    expect("chart: 4 rows is no trend", not chart_notes(trend.split("| 2026-05")[0], sig))
    funds = "| Fund | Fee | Payout | From high |\n|---|---|---|---|\n" + "".join(f"| F{i} | 0.{i}% | 3.{i}% | -{i}% |\n" for i in range(12))
    expect("chart: grid", "compare-grid -> Heat map" in "".join(chart_notes(funds, sig)))
    one = "| Fund | Fee |\n|---|---|\n" + "".join(f"| F{i} | 0.{i}% |\n" for i in range(12))
    expect("chart: compare", "compare-many -> Bar" in "".join(chart_notes(one, sig)))
    lim = "| Claim | Paid | Limit |\n|---|---|---|\n| PT | $95 | $500 |\n"
    expect("chart: limit", "limit -> Meter" in "".join(chart_notes(lim, sig)))
    words = "| Name | Role |\n|---|---|\n" + "".join(f"| N{i} | dev |\n" for i in range(12))
    expect("chart: no numbers, no note", not chart_notes(words, sig))
    expect("chart: words", "before-after -> Dumbbell" in "".join(chart_notes("The rate went from 5.1% to 4.2% at renewal.", sig)))
    expect("chart: words need a number", not chart_notes("There is a risk here.", sig))
    expect("chart: years are no change", not chart_notes("Bonds mature each year from 2027 to 2031.", sig))
    expect("chart: one % is no share", not chart_notes("The US keeps 15% of dividends, a split rule.", sig))
    expect("chart: a share", "share -> Stacked bar" in "".join(chart_notes("The split is 60% stocks and 40% bonds.", sig)))
    expect("chart: one row of text is no KPI", not chart_notes("| Fund | What | Fee | Pays |\n|---|---|---|---|\n| X | a bond fund | 0.2% | 4 |\n", sig))
    sig["data-mention"] = ("a form from the catalog", "the data is not in the doc")
    expect("chart: names a csv", "data-mention" in "".join(chart_notes("Export the CSV from Amex first.", sig)))
    expect("chart: names a sheet", "data-mention" in "".join(chart_notes("The numbers are in the Credit Cards sheet.", sig)))
    expect("chart: cheat sheet is no data", not chart_notes("See the cheat sheet.", sig))
    expect("chart: a table note wins over a mention", "data-mention" not in "".join(chart_notes("From the sheet:\n\n" + lim, sig)))
    del sig["data-mention"]
    expect("chart: code skipped", not chart_notes("```\nrisk out of 100\n```", sig))

    rows12 = "\n".join(f"F{i},0.{i}%" for i in range(12))
    expect("chart: csv block", "csv block" in "".join(chart_notes("```csv\nFund,Fee\n" + rows12 + "\n```", sig)))
    d = pathlib.Path(tempfile.mkdtemp())
    (d / "claims.csv").write_text("Date,Paid\n" + "\n".join(f"2026-0{i}-01,{i}0" for i in range(1, 7)))
    expect("chart: linked csv", "file claims.csv" in "".join(chart_notes("See [claims](claims.csv).", sig, str(d / "doc.md"))))
    (d / "a b.csv").write_text((d / "claims.csv").read_text().replace("2026-0", "0").replace("-01,", "/01/2026,"))
    expect("chart: link with a space, US dates", "file a b.csv" in "".join(chart_notes("[a](a%20b.csv) and [b](<a b.csv>)", sig, str(d / "doc.md"))))
    real_stat = pathlib.Path.stat

    class Offloaded:
        st_flags, st_size = SF_DATALESS, 10
    pathlib.Path.stat = lambda self, **k: Offloaded()
    expect("chart: iCloud-only file skipped, not read", not chart_notes("[c](claims.csv)", sig, str(d / "doc.md")))
    pathlib.Path.stat = real_stat
    expect("chart: missing file, no note", not chart_notes("See [x](nope.csv).", sig, str(d / "doc.md")))
    import zipfile
    with zipfile.ZipFile(d / "lim.xlsx", "w") as z:
        z.writestr("xl/sharedStrings.xml", '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><si><t>Claim</t></si><si><t>Paid</t></si><si><t>Limit</t></si><si><t>PT</t></si></sst>')
        z.writestr("xl/worksheets/sheet1.xml", '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
                   '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c></row>'
                   '<row r="2"><c r="A2" t="s"><v>3</v></c><c r="B2"><v>95</v></c><c r="C2"><v>500</v></c></row></sheetData></worksheet>')
    expect("chart: xlsx read", xlsx_table(d / "lim.xlsx") == (["Claim", "Paid", "Limit"], [["PT", "95", "500"]]))
    expect("chart: linked xlsx", "file lim.xlsx" in "".join(chart_notes("Data: [sheet](lim.xlsx)", sig, str(d / "doc.md"))))
    (d / "bad.xlsx").write_text("not a zip")
    expect("chart: broken xlsx, no note", not chart_notes("[b](bad.xlsx)", sig, str(d / "doc.md")))
    max_saved = DATA_MAX_BYTES
    globals()["DATA_MAX_BYTES"] = 10
    expect("chart: large file skipped", not chart_notes("[c](claims.csv)", sig, str(d / "doc.md")))
    globals()["DATA_MAX_BYTES"] = max_saved
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
        f.write("## Signal table\n\n| Signal | Kind | Test | Form | Why |\n|---|---|---|---|---|\n| limit | table | x | Meter | one value against its limit |\n")
    expect("chart: reads the catalog", chart_signals(pathlib.Path(f.name)) == {"limit": ("Meter", "one value against its limit")})
    expect("chart: no catalog", chart_signals(pathlib.Path("/nonexistent.md")) is None)
    cat_saved, CHART_CATALOG = CHART_CATALOG, pathlib.Path(f.name)
    out = hook("post", {"tool_input": {"file_path": "a.md", "content": "Claims so far:\n\n" + lim}}, md)
    expect("chart: a clean edit gets context, not a block", out and "additionalContext" in out and "decision" not in out)
    out = hook("post", {"tool_input": {"file_path": "a.md", "content": bad + "\n\n" + lim}}, md)
    expect("chart: a failing edit carries the note in its block", out and json.loads(out)["decision"] == "block" and "Chart note" in out)
    CHART_CATALOG = cat_saved
    pathlib.Path(f.name).unlink()

    # The public clone (R18, R19): the rules file alone, with no .claude/CLAUDE.md.
    no_terms = rules_text(with_terms=False)
    r = check("Put it in the vault.", no_terms)  # catches: a crash or a fail with no Terms table
    expect("termsOptional: no Terms table, the term rules pass", r["checkedTerms"][0] == 1 and r["otherTerms"][0] == 1)
    msg = report(check("It works; mostly.", md)) or ""
    expect("messageNamesRules: a message names the rules file", RULES.name in msg and "CLAUDE.md" not in msg)
    msg = report(check("Put it in the vault.", md)) or ""
    expect("messageNamesRules: a term fail names .claude/CLAUDE.md", ".claude/CLAUDE.md" in msg)

    def public_run(args, stdin="", with_rules=True):
        """Run a copy of the script in a throwaway clone with an empty HOME: (exit code, stdout, stderr)."""
        import subprocess
        root = pathlib.Path(tempfile.mkdtemp())
        (root / ".claude/hooks").mkdir(parents=True)
        (root / ".claude/hooks/writing-check.py").write_text(pathlib.Path(__file__).read_text())
        if with_rules:
            (root / ".claude/hooks" / RULES.name).write_text(RULES.read_text())
        home = root / "home"
        home.mkdir()
        p = subprocess.run([sys.executable, "-I", str(root / ".claude/hooks/writing-check.py"), *args],
                           input=stdin, capture_output=True, text=True, env={"HOME": str(home), "PATH": "/usr/bin:/bin"})
        return p.returncode, p.stdout, p.stderr

    code, out, err = public_run(["report"])
    expect("reportNeedsOnlyRules, initPublic: report runs with only the rules file", code == 0 and "bannedWords" in out and not err)
    edit = json.dumps({"tool_input": {"file_path": "a.md", "content": bad}})
    code, out, err = public_run(["post"], edit)
    expect("public clone: a bad edit is blocked", code == 0 and json.loads(out or "{}").get("decision") == "block")
    code, out, err = public_run(["post"], edit, with_rules=False)
    expect("hookExitsZero, failed_open: no rules file, the hook exits 0 with one line",
           code == 0 and not out and len(err.strip().splitlines()) == 1)
    code, out, err = public_run(["stop"], json.dumps({"stop_hook_active": True, "last_assistant_message": bad}), with_rules=False)
    expect("stopBlocksOnce, skip before the read: quiet with no rules file", code == 0 and not out and not err)
    code, out, err = public_run(["report"], with_rules=False)
    expect("failed: report with no rules file exits 1 with one line", code == 1 and len(err.strip().splitlines()) == 1)

    for name in fails:
        print(f"FAIL {name}")
    print("ok" if not fails else f"{len(fails)} failed")
    return 1 if fails else 0


RULE_TEXT = {
    "bannedWords": 'no word from "Words not to use"',
    "checkedTerms": 'no "Never call it" term',
    "filler": 'no phrase from "Phrases not to use"',
    "aiTells": 'no word from "AI tells"',
    "fullPaths": "replies only: each code or .md path from / or ~/",
    "repeatedWord": 'no "the the"',
    "semicolons": "no ;",
    "dashes": "no em dash or --",
    "paragraphs": "3 sentences or fewer per paragraph",
    "length": "20 words per step, 25 per other sentence",
    "passive": "no is/was + participle",
    "emoji": "no emoji (a status emoji on an item is fine)",
    "weakWords": 'no "very", "really", ...',
    "otherTerms": 'no "in this sense" term',
    "readability": "Flesch / 100, text of 30 words or more",
    "contractions": "share of don't over do not",
    "rhythm": "spread of sentence lengths, 5+ sentences",
    "person": "has I, you or we, 30 words or more",
    "steWords": "no word the STE dictionary rejects",
}


def overview(md, days=7, session=""):
    """The rules with their thresholds and the log of the last `days` days in one table,
    then the check count of one session, then the speed, as text. A tab starts the "Passes when"
    text of each rule row: the pane shows it on hover."""
    def cell(r, t):
        return "off" if t == 0 else f"{t:.2f}" if r in WHOLE else f"{t:.0%}"

    since = time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(time.time() - days * 86400))
    rows = []
    try:
        for line in LOG.read_text().splitlines():
            d = json.loads(line)
            if d.get("time", "") >= since and "/" in d.get("kind", "") and not d["kind"].startswith("chart/"):
                rows.append(d)
    except (OSError, ValueError):
        pass
    week = log_stats(rows)

    out = [f"Writing check   reply: {mode('reply')}   docs: {mode('docs')}",
           f"Thresholds: top of {pathlib.Path(__file__).resolve()}",
           f"Median, Mean, Fails: last {days} days, {len(rows)} checks ({LOG})", ""]
    out.append(f"{'Rule':<14}{'Pro':>6}{'Casual':>8}{'Median':>8}{'Mean':>7}{'Fails':>12}\tPasses when")
    # Most failed first, then the strictest.
    for r in sorted(THRESHOLDS, key=lambda r: (-week.get(r, ("", 0))[1], -THRESHOLDS[r] - CASUAL[r], r)):
        out.append(f"{r:<14}{cell(r, THRESHOLDS[r]):>6}{cell(r, CASUAL[r]):>8}{week.get(r, ('',))[0]:<27}"
                   f"\t{RULE_TEXT.get(r, '')}")
    out += ste_table(rows)

    if session:
        out += ["", f"This session ({session[:8]}): {sum(d.get('session') == session for d in rows)} checks"]

    src = md.split()
    out += ["", "Speed, rules only (a hook run adds about 40 ms to start Python and load the lists)"]
    for n in (100, 1000, 10000):
        text = " ".join((src * (n // len(src) + 1))[:n])
        t = time.perf_counter()
        check(text, md)
        out.append(f"  {n:>6} words: {(time.perf_counter() - t) * 1000:.0f} ms")
    return "\n".join(out)


def log_stats(rows):
    """Per rule: median score, mean score, and fails of checks (the miss rate), as one
    27-column cell, and the miss rate."""
    out = {}
    for r in THRESHOLDS:
        got = [d for d in rows if r in d["scores"]]
        if not got:
            continue
        scores = sorted(d["scores"][r] for d in got)
        fails = sum(d["scores"][r] < (CASUAL if d["kind"].endswith("casual") else THRESHOLDS)[r] for d in got)
        out[r] = (f"{scores[len(scores) // 2]:>8.2f}{sum(scores) / len(scores):>7.2f}"
                  f"{f'{fails}/{len(got)} {fails / len(got):.0%}':>12}", fails / len(got))
    return out


def ste_table(rows):
    """The rejected STE words used most, with the approved words to use instead."""
    ste = {}
    for d in rows:
        for w, n in d.get("ste", {}).items():
            ste[w] = ste.get(w, 0) + n
    if not ste:
        return []
    rejected = ste_rejected()
    out = ["", "Words the STE dictionary rejects, most used in the last 7 days",
           f"{'STE word':<16}{'Uses':>5}  Use instead"]
    for w, n in sorted(ste.items(), key=lambda x: -x[1])[:15]:
        out.append(f"{w:<16}{n:>5}  {', '.join(rejected.get(w, [])[:3]) or '(technical name?)'}")
    return out


def ste_setup():
    """Download the wheel of STE_PACKAGE, without installing it, and keep only its dictionary."""
    import subprocess, tempfile, zipfile
    with tempfile.TemporaryDirectory() as tmp:
        r = subprocess.run([sys.executable, "-m", "pip", "download", "--no-deps", "-q", "-d", tmp, STE_PACKAGE])
        wheels = list(pathlib.Path(tmp).glob("*.whl"))
        if r.returncode or not wheels:
            print(f"ste-setup: pip download {STE_PACKAGE} failed", file=sys.stderr)
            return 1
        with zipfile.ZipFile(wheels[0]) as z:
            data = z.read(next(n for n in z.namelist() if n.endswith("/" + STE_FILE.name)))
    STE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STE_FILE.write_bytes(data)
    print(f"ste-setup: {STE_FILE} ({len(data)} bytes)")
    return 0


def main():
    global LOG
    args = sys.argv[1:]
    if args == ["--test"]:
        LOG = pathlib.Path("/dev/null")
        return test()
    if args == ["ste-setup"]:
        return ste_setup()
    if args[:1] in (["report"], ["file"]):
        try:
            md = rules_text()
        except OSError as e:
            print(f"writing-check: {e}", file=sys.stderr)
            return 1
    if args[:1] == ["report"] and len(args) <= 2:
        print(overview(md, session=args[1] if len(args) == 2 else ""))
        return 0
    if args[:1] == ["file"] and len(args) == 2:
        msg = report(check(pathlib.Path(args[1]).read_text(), md))
        print(msg or "ok")
        return 1 if msg else 0
    if args in (["post"], ["stop"]):
        try:
            data = json.load(sys.stdin)
            out = hook(args[0], data)
        except Exception as e:  # a broken check must never break the session
            print(f"writing-check: {e}", file=sys.stderr)
            return 0
        # A reply is only logged, since a Stop message shows to the user. A short path blocks it once (R12).
        if out and (args[0] == "post" or "FAIL fullPaths" in out):
            print(out)
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
