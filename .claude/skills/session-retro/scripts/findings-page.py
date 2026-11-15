"""Write, merge, check and list the findings pages of the session retro.

Usage:
  findings-page.py full <session_id> <first entry date> <findings.json>   prints the pending page
  findings-page.py cold <session_id> <first entry date> <minutes>         prints the pending page, or "kept"
  findings-page.py move <pending page>     into the KB if clean, else into rejected/; prints where
  findings-page.py check <page>            exit 1 if the page matches a secret pattern
  findings-page.py confirmed               the confirmed findings of all pages
  findings-page.py summary                 the open count and the patterns, for the reminder

A page is written in $SESSION_RETRO_STATE/pending/ first, and moves into
$SESSION_RETRO_KB/claude-research/session-retro/ only when no secret pattern matches.
"""
import json, os, re, shutil, sys
from collections import defaultdict
from pathlib import Path

STATE = Path(os.environ.get("SESSION_RETRO_STATE") or Path.home() / ".claude/session-retro")
KB = Path(os.environ.get("SESSION_RETRO_KB") or Path.home() / "second-brain/personal")
PAGES = KB / "claude-research/session-retro"

SECRETS = {
    "anthropic key": r"sk-ant-[A-Za-z0-9_-]{20,}",
    "github token": r"gh[pousr]_[A-Za-z0-9]{30,}",
    "aws key id": r"AKIA[0-9A-Z]{16}",
    "bearer token": r"Bearer [A-Za-z0-9._-]{20,}",
    "password field": r"(?i)(password|passwd|pwd)\\?[\"']?\s*[:=]\s*\\?[\"']?[^\"'\s\\,}]{6,}",
    "api key field": r"(?i)(api[_-]?key|secret[_-]?key|client[_-]?secret)\\?[\"']?\s*[:=]\s*\\?[\"']?[A-Za-z0-9._-]{16,}",
    "secret key": r"\b(sk-[A-Za-z0-9_-]{20,}|xox[abpr]-[A-Za-z0-9-]{10,})",
    "private key": r"-----BEGIN [A-Z ]*PRIVATE KEY-----",
    "token field": r"(?i)(access|refresh)_token\\?[\"']?\s*[:=]\s*\\?[\"'][A-Za-z0-9._-]{16,}",
}
CARD = r"(?<![\w-])(?:[3-6]\d{3}(?:[ -]?\d{4}){3}|3[47]\d{2}[ -]?\d{6}[ -]?\d{5})(?![\w-])"  # 16 or 15 digits, not inside a session ID
FIELDS = [("Kind", "kind"), ("Count", "count"), ("Event", "event"), ("Cause", "cause"), ("Right", "right"),
          ("Avoidable", "avoidable"), ("Change", "change"), ("Tip", "tip")]
HEAD = re.compile(r"^### (F-[0-9a-f]{8}) ", re.M)


def luhn(digits):
    d = [int(c) for c in digits][::-1]
    return (sum(d[0::2]) + sum(sum(divmod(2 * x, 10)) for x in d[1::2])) % 10 == 0


def secret(text):
    """The name of the first secret pattern the text matches, or None."""
    for name, pat in SECRETS.items():
        if re.search(pat, text):
            return name
    if any(luhn(re.sub(r"\D", "", m)) for m in re.findall(CARD, text)):
        return "card number"
    return None


def find_page(sid):
    pages = sorted(PAGES.glob(f"*-{sid[:8]}.staging.md"))
    return pages[0] if pages else None


def statuses(text):
    """{finding id: status} of a page."""
    out = {}
    heads = list(HEAD.finditer(text))
    for m, nxt in zip(heads, heads[1:] + [None]):
        s = re.search(r"^- Status: (\w+)", text[m.end():nxt.start() if nxt else len(text)], re.M)
        out[m.group(1)] = s.group(1).lower() if s else "open"
    return out


def header(sid, mode):
    return (f"# Session retro: {sid[:8]}\n\n"
            "Staging page. Claude wrote it after the session ended. Nothing here is confirmed.\n\n"
            f"- Session: `{sid}`\n- Retro: {mode}\n\n")


def pending(name, text):
    p = STATE / "pending" / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)
    return p


def full(sid, date, findings_json):
    old = find_page(sid)
    kept = statuses(old.read_text()) if old else {}
    findings = json.loads(Path(findings_json).read_text())
    out = [header(sid, "full")]
    if not findings:
        out.append("No findings.\n")
    else:
        out.append("To settle a finding, change only its `Status:` line to `confirmed` or `dropped`. A run again keeps it.\n")
    for f in findings:
        out.append(f"\n### {f['id']} {f['kind']}: {f.get('subject', '')}\n\n")
        out.append(f"- Status: {kept.get(f['id'], 'open')}\n")
        out.append(f"- Where: session `{sid}`, transcript line `{f['uuid']}`\n")
        out += [f"- {label}: {f[key]}\n" for label, key in FIELDS if f.get(key) not in (None, "")]
    # A finding of an earlier run that this run did not return stays, as it stands.
    new_ids = {f["id"] for f in findings}
    if old:
        old_text = old.read_text()
        heads = list(HEAD.finditer(old_text))
        for m, nxt in zip(heads, heads[1:] + [None]):
            if m.group(1) not in new_ids:
                out.append("\n" + old_text[m.start():nxt.start() if nxt else len(old_text)].strip("\n") + "\n")
    if findings or (old and any(h not in new_ids for h in kept)):
        out[1] = "To settle a finding, change only its `Status:` line to `confirmed` or `dropped`. A run again keeps it.\n"
    name = old.name if old else f"{date}-{sid[:8]}.staging.md"
    return pending(name, "".join(out))


def cold(sid, date, minutes):
    old = find_page(sid)
    if old and "- Retro: full" in old.read_text():
        return "kept"
    text = header(sid, "cold") + f"Not read: the last transcript entry is {minutes} minutes old.\n"
    return pending(old.name if old else f"{date}-{sid[:8]}.staging.md", text)


def move(page):
    page = Path(page)
    hit = secret(page.read_text())
    if hit:
        dest = STATE / "rejected" / page.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(page, dest)
        print(f"refused: the page matches the secret pattern '{hit}'. It is in {dest}")
        return 1
    PAGES.mkdir(parents=True, exist_ok=True)
    dest = PAGES / page.name
    shutil.move(page, dest)
    print(dest)
    return 0


def all_findings():
    """(session, id, kind, subject, status) of each finding on each page."""
    for page in sorted(PAGES.glob("*.staging.md")):
        text = page.read_text()
        sid = re.search(r"^- Session: `([^`]+)`", text, re.M)
        st = statuses(text)
        for m in re.finditer(r"^### (F-[0-9a-f]{8}) (\w+): (.*)$", text, re.M):
            yield (sid.group(1) if sid else page.name, m.group(1), m.group(2), m.group(3).strip(), st.get(m.group(1), "open"))


def confirmed():
    for sid, fid, kind, subject, status in all_findings():
        if status == "confirmed":
            print(f"{fid} {kind}: {subject} (session {sid})")
    return 0


def summary():
    rows = list(all_findings())
    open_rows = [r for r in rows if r[4] == "open"]
    sessions = defaultdict(set)
    for sid, _, kind, subject, _ in open_rows:
        sessions[(kind, subject)].add(sid)
    print(f"{len(open_rows)} open findings in {PAGES}")
    for (kind, subject), s in sorted(sessions.items()):
        if len(s) >= 2:
            print(f"- pattern: {kind}: {subject}, in {len(s)} sessions")
    return 0


def main(argv):
    cmd, args = (argv[1], argv[2:]) if len(argv) > 1 else ("", [])
    if cmd == "full" and len(args) == 3:
        print(full(*args))
    elif cmd == "cold" and len(args) == 3:
        print(cold(*args))
    elif cmd == "move" and len(args) == 1:
        return move(args[0])
    elif cmd == "check" and len(args) == 1:
        hit = secret(Path(args[0]).read_text())
        if hit:
            print(f"{args[0]}: matches the secret pattern '{hit}'")
        return 1 if hit else 0
    elif cmd == "confirmed" and not args:
        return confirmed()
    elif cmd == "summary" and not args:
        return summary()
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
