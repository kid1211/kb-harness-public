"""Unit tests of findings-page.py. Cases follow the runs of findings-page.qnt.

Run: python3 -I tests/skills/session-retro/test-findings-page.py [name] [--script <path>]
A name runs only the tests whose name holds it. --script runs them on a broken copy, for a fixture run.
"""
import json, os, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / ".claude/skills/session-retro/scripts/findings-page.py"
SID = "abcdef12-3456-7890-abcd-ef1234567890"
SID2 = "99999999-0000-0000-0000-0000000000aa"


def finding(kind="hook_block", subject="writing-check.py", uuid="u-1", fid=None, status=None):
    f = {"id": fid or f"F-{abs(hash((kind, subject))) % 16**8:08x}", "kind": kind, "subject": subject, "uuid": uuid,
         "count": 2, "event": "The hook blocked a Write.", "cause": "A sentence was too long.",
         "change": "None.", "tip": "None.", "right": "yes", "avoidable": "yes"}
    if status:
        f["status"] = status
    return f


class Env:
    def __init__(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.kb = self.tmp / "kb"
        (self.kb / "claude-research/session-retro").mkdir(parents=True)
        (self.kb / ".claude").mkdir()
        (self.kb / ".claude/CLAUDE.md").symlink_to(ROOT / ".claude/CLAUDE.md")  # what makes a folder a KB
        self.state = self.tmp / "state"
        self.env = {**os.environ, "SESSION_RETRO_STATE": str(self.state), "SESSION_RETRO_KB": str(self.kb)}

    def run(self, *args, stdin=None):
        return subprocess.run([sys.executable, "-I", str(SCRIPT), *map(str, args)], capture_output=True, text=True, env=self.env, input=stdin)

    def full(self, findings, sid=SID, date="2026-10-24"):
        p = self.tmp / "f.json"
        p.write_text(json.dumps(findings))
        r = self.run("full", sid, date, p)
        assert r.returncode == 0, r.stderr
        return Path(r.stdout.strip())

    def cold(self, minutes=90, sid=SID, date="2026-10-24"):
        r = self.run("cold", sid, date, minutes)
        assert r.returncode == 0, r.stderr
        return r.stdout.strip()

    def move(self, pending):
        return self.run("move", pending)

    def page(self, sid=SID):
        pages = list((self.kb / "claude-research/session-retro").glob(f"*-{sid[:8]}.staging.md"))
        return pages[0] if len(pages) == 1 else None


def set_status(page, fid, status):
    text = page.read_text()
    head = text.index(f"### {fid}")
    i = text.index("- Status: open", head)
    page.write_text(text[:i] + f"- Status: {status}" + text[i + len("- Status: open"):])


# --- runCold, coldHasNoFindings
def test_cold_on_no_page_writes_one_line():
    e = Env()
    e.move(e.cold(90))
    text = e.page().read_text()
    assert "Not read: the last transcript entry is 90 minutes old." in text
    assert "### F-" not in text


# --- fullStaysFull: a cold run on a full page leaves it as it was
def test_cold_on_full_page_keeps_it():
    e = Env()
    e.move(e.full([finding()]))
    before = e.page().read_text()
    out = e.cold(90)
    assert out == "kept", out
    assert e.page().read_text() == before


# --- runFull: a full run on a cold page writes the findings
def test_full_on_cold_page_writes_findings():
    e = Env()
    e.move(e.cold(90))
    e.move(e.full([finding()]))
    text = e.page().read_text()
    assert "Not read" not in text and "### F-" in text and "- Status: open" in text


# --- runFull, onlyUserSets: a run again keeps statuses and adds new findings as open
def test_rerun_keeps_status():
    e = Env()
    a, b = finding(subject="a.sh", fid="F-0000000a"), finding(subject="b.sh", fid="F-0000000b")
    e.move(e.full([a, b]))
    set_status(e.page(), "F-0000000a", "confirmed")
    set_status(e.page(), "F-0000000b", "dropped")
    c = finding(subject="c.sh", fid="F-0000000c")
    e.move(e.full([b, c, a]))
    text = e.page().read_text()
    def status(fid):
        i = text.index(f"### {fid}")
        return text[i:].split("- Status: ", 1)[1].split("\n", 1)[0]
    assert (status("F-0000000a"), status("F-0000000b"), status("F-0000000c")) == ("confirmed", "dropped", "open")


# --- runFull: a finding the run again does not return stays, with its status
def test_rerun_keeps_dropped_out_finding():
    e = Env()
    e.move(e.full([finding(subject="a.sh", fid="F-0000000a")]))
    set_status(e.page(), "F-0000000a", "confirmed")
    e.move(e.full([finding(subject="c.sh", fid="F-0000000c")]))
    text = e.page().read_text()
    i = text.index("### F-0000000a")
    assert "- Status: confirmed" in text[i:i + 200] and "### F-0000000c" in text, text


# --- statuses: one finding's status never comes from the next, and a capital letter counts
def test_status_scope_and_case():
    e = Env()
    e.move(e.full([finding(subject="a.sh", fid="F-0000000a"), finding(subject="b.sh", fid="F-0000000b")]))
    p = e.page()
    text = p.read_text()
    i = text.index("### F-0000000a")
    j = text.index("- Status: open", i)
    text = text[:j] + text[j + len("- Status: open\n"):]
    p.write_text(text)
    set_status(p, "F-0000000b", "Confirmed")
    out = e.run("confirmed").stdout
    assert "F-0000000b" in out and "F-0000000a" not in out, out


# --- runFull: a run on a later date finds the page by the session ID
def test_rerun_later_date_same_page():
    e = Env()
    e.move(e.full([finding()], date="2026-10-24"))
    e.move(e.full([finding()], date="2026-10-30"))
    pages = list((e.kb / "claude-research/session-retro").glob("*.staging.md"))
    assert len(pages) == 1 and pages[0].name.startswith("2026-10-24-"), pages


# --- onlyUserSets: the retro never writes a status other than open
def test_retro_status_is_open():
    e = Env()
    e.move(e.full([finding(status="confirmed")]))
    assert "- Status: confirmed" not in e.page().read_text()


# --- moveIn, kbHasNoSecret: a page with a secret stays out of the KB
def test_move_refuses_secret():
    fake = {
        "password": "password=hunter22x",
        "api key": "api_key: " + "ABCDEFGHIJKLMNOP" + "1234",
        "slack": "xoxb-1234567890-abcdef",
        "private key": "-----BEGIN RSA PRIVATE KEY-----",
        "token": "access_token: '" + "abcdefghijklmnop" + "1234'",
        "aws": "AKIA" + "ABCDEFGHIJKLMNOP",
        "escaped": 'refresh_token\\": \\"abcdefghijklmnop1234',
    }
    for name, value in fake.items():
        e = Env()
        f = finding()
        f["event"] = f"The call held {value}."
        r = e.move(e.full([f]))
        assert r.returncode == 1, (name, r.stdout)
        assert e.page() is None, name
        assert list((e.state / "rejected").glob("*.staging.md")), name


# --- moveIn: a clean page goes into the KB
def test_move_puts_clean_page_in_kb():
    e = Env()
    r = e.move(e.full([finding()]))
    assert r.returncode == 0, r.stdout + r.stderr
    assert e.page() is not None and Path(r.stdout.strip()) == e.page()


# --- check: a card number passes the Luhn test, other 16 digits do not match
def test_check_card_luhn():
    e = Env()
    p = e.tmp / "p.md"
    p.write_text("id 1234 5678 9012 3456\n")
    assert e.run("check", p).returncode == 0
    p.write_text("card " + " ".join(["4111"] + ["1111"] * 3) + "\n")
    assert e.run("check", p).returncode == 1
    p.write_text("session 99999999-0000-0000-0000-" + "0" * 12 + "\n")
    assert e.run("check", p).returncode == 0


# --- runFull: a session with no findings
def test_no_findings():
    e = Env()
    e.move(e.full([]))
    assert "No findings." in e.page().read_text()


# --- the page names the session and each transcript uuid, and passes kb-check
def test_page_links_and_kb_check():
    e = Env()
    e.move(e.full([finding(uuid="u-77")]))
    text = e.page().read_text()
    assert SID in text and "`u-77`" in text
    r = subprocess.run([sys.executable, "-I", str(ROOT / ".claude/skills/kb/scripts/kb-check.py"), "file", str(e.page())], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout


# --- confirmed: lists the confirmed findings of all pages
def test_confirmed_lists():
    e = Env()
    e.move(e.full([finding(subject="a.sh", fid="F-0000000a"), finding(subject="b.sh", fid="F-0000000b")]))
    set_status(e.page(), "F-0000000a", "confirmed")
    out = e.run("confirmed").stdout
    assert "F-0000000a" in out and "F-0000000b" not in out


# --- summary: open count over pages, and a pattern in 2 sessions
def test_summary_pattern():
    e = Env()
    e.move(e.full([finding(subject="writing-check.py", fid="F-0000000a")]))
    e.move(e.full([finding(subject="writing-check.py", fid="F-0000000a"), finding(subject="x.sh", fid="F-0000000b")], sid=SID2))
    out = e.run("summary").stdout
    assert "3 open findings" in out, out
    assert "hook_block: writing-check.py, in 2 sessions" in out, out
    assert "x.sh" not in out


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--script" in args:
        i = args.index("--script")
        SCRIPT = Path(args[i + 1])
        del args[i:i + 2]
    only = args[0] if args else ""
    tests = [(n, f) for n, f in sorted(globals().items()) if n.startswith("test_") and only in n]
    bad = 0
    for n, f in tests:
        try:
            f()
            print(f"ok   {n}")
        except Exception as ex:
            bad += 1
            print(f"FAIL {n}: {type(ex).__name__}: {ex}")
    print(f"{len(tests) - bad} passed, {bad} failed")
    sys.exit(1 if bad or not tests else 0)
