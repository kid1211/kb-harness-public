"""Unit tests of findings.py, on small transcripts each test writes.

Run: python3 -I tests/skills/session-retro/test-findings.py [name] [--script <path>]
A name runs only the tests whose name holds it. --script runs them on a broken copy, for a fixture run.
"""
import json, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / ".claude/skills/session-retro/scripts/findings.py"


class T:
    """A transcript, one JSON line per entry."""
    def __init__(self):
        self.lines, self.n = [], 0

    def add(self, **o):
        self.n += 1
        o.setdefault("uuid", f"u-{self.n}")
        o.setdefault("timestamp", "2026-10-24T10:00:00.000Z")
        self.lines.append(o)
        return o["uuid"]

    def call(self, name, inp, result="ok", error=False):
        tid = f"t-{self.n + 1}"
        u = self.add(type="assistant", message={"model": "claude-opus-5-5", "content": [{"type": "tool_use", "id": tid, "name": name, "input": inp}]})
        self.add(type="user", message={"content": [{"type": "tool_result", "tool_use_id": tid, "content": result, "is_error": error}]})
        return u

    def say(self, text):
        return self.add(type="assistant", message={"model": "claude-opus-5-5", "content": [{"type": "text", "text": text}]})

    def user(self, text):
        return self.add(type="user", message={"content": text})

    def hook_block(self, script, event="PostToolUse:Edit"):
        return self.add(type="attachment", attachment={"type": "hook_blocking_error", "hookName": event, "hookEvent": event.split(":")[0],
                        "blockingError": {"blockingError": "the rule broke", "command": f'"$(git rev-parse --show-toplevel)"/.claude/hooks/{script} post'}})

    def write(self):
        p = Path(tempfile.mkdtemp()) / "t.jsonl"
        p.write_text("".join(json.dumps(o) + "\n" for o in self.lines))
        return p


def scan(t):
    r = subprocess.run([sys.executable, "-I", str(SCRIPT), "scan", str(t.write())], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


def kinds(cands):
    return sorted((c["kind"], c["count"]) for c in cands)


def check(t, text):
    p = t.write()
    out = p.parent / "out.txt"
    out.write_text(text)
    r = subprocess.run([sys.executable, "-I", str(SCRIPT), "check", str(p), str(out)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


# --- each block shape gives one candidate of its kind
def test_scan_block_shapes():
    t = T()
    t.say("hi")
    t.hook_block("writing-check.py")
    # A Stop block writes an attachment and a summary line. The summary lists every Stop hook.
    t.add(type="attachment", attachment={"type": "hook_blocking_error", "hookName": "Stop", "hookEvent": "Stop",
                                         "blockingError": {"blockingError": "too long", "command": ".claude/hooks/writing-check.py stop"}})
    t.add(type="system", subtype="stop_hook_summary", hookErrors=["too long"], preventedContinuation=False,
          hookInfos=[{"command": ".claude/hooks/kb-commit-nudge.sh stop"}, {"command": ".claude/hooks/writing-check.py stop"}])
    t.call("Write", {"file_path": "/a.md", "content": "x"}, result="PreToolUse:Write hook error: [.claude/skills/kb/hooks/kb-guard.sh]: no", error=True)
    t.call("Bash", {"command": "rm -rf /"}, result="Permission for this action was denied by the Claude Code auto mode classifier. Reason: no", error=True)
    t.call("Bash", {"command": "git status"}, result="This session is isolated in the worktree /x, but this command ...", error=True)
    t.call("Bash", {"command": "rm x"}, result="The user doesn't want to proceed with this tool use.", error=True)
    t.add(type="attachment", attachment={"type": "hook_non_blocking_error", "hookName": "SessionStart", "stderr": "No such file",
                                         "command": ".claude/hooks/deep-research-reminder.sh"})
    got = sorted((c["kind"], c["subject"], c["count"]) for c in scan(t))
    want = sorted([("hook_block", "writing-check.py", 1), ("hook_stop_block", "writing-check.py", 1),
                   ("hook_block", "kb-guard.sh", 1), ("guard_block", "This session is isolated in the worktree", 1),
                   ("guard_block", "Permission for this action was denied by the Claude Code auto mode classifier", 1),
                   ("user_rejected", "Bash", 1), ("hook_failed", "deep-research-reminder.sh", 1)])
    assert got == want, got


# --- two blocks by one hook give one group with count 2
def test_scan_block_group_count():
    t = T()
    first = t.hook_block("writing-check.py")
    t.hook_block("writing-check.py")
    c = scan(t)
    assert len(c) == 1 and c[0]["count"] == 2 and c[0]["uuid"] == first, c


# --- the same call twice is a loop; a call after an error is not
def test_scan_repeated_call():
    t = T()
    t.call("Grep", {"pattern": "x"})
    t.call("Grep", {"pattern": "x"})
    assert ("repeated_call", 1) in kinds(scan(t))
    t = T()
    t.call("Bash", {"command": "ls"}, result="boom", error=True)
    t.call("Bash", {"command": "ls"})
    assert scan(t) == []


# --- a test run again after an Edit is not a loop
def test_scan_rerun_after_edit():
    t = T()
    t.call("Bash", {"command": "pytest"})
    t.call("Edit", {"file_path": "/a.py", "old_string": "1", "new_string": "2"})
    t.call("Bash", {"command": "pytest"})
    assert scan(t) == []


# --- a Read again with no change between is a loop; after an Edit it is not
def test_scan_reread():
    t = T()
    t.call("Read", {"file_path": "/a.md"})
    t.call("Grep", {"pattern": "y"})
    t.call("Read", {"file_path": "/a.md", "limit": 5})
    assert ("reread", 1) in kinds(scan(t))
    t = T()
    t.call("Read", {"file_path": "/a.md"})
    t.call("Edit", {"file_path": "/a.md", "old_string": "1", "new_string": "2"})
    t.call("Read", {"file_path": "/a.md", "limit": 5})
    assert scan(t) == []


# --- an Edit back to the old text is undo_redo
def test_scan_undo_redo():
    t = T()
    t.call("Edit", {"file_path": "/a.py", "old_string": "x", "new_string": "y"})
    t.call("Edit", {"file_path": "/a.py", "old_string": "y", "new_string": "x"})
    assert ("undo_redo", 1) in kinds(scan(t))


# --- a user text turn after a reply is a candidate, an interrupt too; a rejection is a block, not a turn
def test_scan_user_turns():
    t = T()
    t.user("build it")
    t.say("done")
    u = t.user("no, I meant the other one")
    t.add(type="user", message={"content": [{"type": "text", "text": "[Request interrupted by user]"}]})
    c = scan(t)
    turns = [x for x in c if x["kind"] == "user_turn"]
    assert len(turns) == 1 and turns[0]["uuid"] == u, c
    assert any(x["kind"] == "interrupt" for x in c), c
    t = T()
    t.say("go")
    t.call("Bash", {"command": "rm x"}, result="The user doesn't want to proceed with this tool use.", error=True)
    assert [x["kind"] for x in scan(t)] == ["user_rejected"]


# --- a candidate before the last compaction is unseen
def test_scan_unseen_before_compaction():
    t = T()
    t.hook_block("a.sh")
    t.add(type="system", subtype="compact_boundary")
    t.hook_block("b.sh")
    t.hook_block("c.sh")
    t.add(type="system", subtype="compact_boundary")
    t.hook_block("b.sh")
    got = {c["subject"]: c.get("unseen", False) for c in scan(t)}
    assert got == {"a.sh": True, "b.sh": False, "c.sh": True}, got


# --- check drops a kind not on the list, and a uuid not in the transcript
def test_check_drops():
    t = T()
    u = t.hook_block("a.sh")
    out = check(t, json.dumps([{"kind": "hook_block", "uuid": u, "subject": "a.sh"}, {"kind": "made_up", "uuid": u, "subject": "x"},
                               {"kind": "circle", "uuid": "u-999", "subject": "y"}]))
    assert [f["kind"] for f in out] == ["hook_block"], out


# --- check takes the JSON list out of the text around it
def test_check_extracts_json():
    t = T()
    u = t.hook_block("a.sh")
    out = check(t, "Here are the findings:\n```json\n" + json.dumps([{"kind": "hook_block", "uuid": u, "subject": "a.sh"}]) + "\n```\nDone.")
    assert len(out) == 1


# --- check gives the same id to the same finding in another order, and keeps the scan's subject and count
def test_check_stable_ids():
    t = T()
    a = t.hook_block("a.sh")
    t.hook_block("a.sh")
    b = t.user("no, the other one")
    f1 = {"kind": "hook_block", "uuid": a, "subject": "the writing hook"}
    f2 = {"kind": "misunderstood_request", "uuid": b, "subject": "which file"}
    x, y = check(t, json.dumps([f1, f2])), check(t, json.dumps([f2, f1]))
    assert {f["kind"]: f["id"] for f in x} == {f["kind"]: f["id"] for f in y}
    blk = next(f for f in x if f["kind"] == "hook_block")
    assert blk["subject"] == "a.sh" and blk["count"] == 2, blk
    # two circles the model ties to one uuid get two IDs
    c = check(t, json.dumps([{"kind": "circle", "uuid": b, "subject": "one"}, {"kind": "circle", "uuid": b, "subject": "two"}]))
    assert len({f["id"] for f in c}) == 2, c


# --- R9: check takes unseen from the scan, and a block of an unseen candidate says unknown
def test_check_unseen_from_scan():
    t = T()
    u = t.hook_block("a.sh")
    t.add(type="system", subtype="compact_boundary")
    v = t.hook_block("b.sh")
    out = check(t, json.dumps([{"kind": "hook_block", "uuid": u, "subject": "a.sh", "right": "yes", "unseen": False},
                               {"kind": "hook_block", "uuid": v, "subject": "b.sh", "right": "yes", "unseen": True},
                               {"kind": "circle", "uuid": v, "subject": "own", "unseen": True}]))
    by = {f["subject"]: f for f in out}
    assert by["a.sh"]["right"] == "unknown" and by["a.sh"]["unseen"] is True, by
    assert by["b.sh"]["right"] == "yes" and by["b.sh"]["unseen"] is False, by
    assert by["own"]["unseen"] is False, by


# --- R8: a candidate the fork leaves out is not a finding. A finding the fork adds stays
def test_check_fork_may_drop():
    t = T()
    u = t.hook_block("a.sh")
    t.hook_block("b.sh")
    assert check(t, "[]") == []
    out = check(t, json.dumps([{"kind": "circle", "uuid": u, "subject": "own"}]))
    assert [f["subject"] for f in out] == ["own"], out


# --- R10: one finding for each id, the first
def test_check_one_id():
    t = T()
    u = t.hook_block("a.sh")
    out = check(t, json.dumps([{"kind": "hook_block", "uuid": u, "subject": "x", "right": "yes"},
                               {"kind": "hook_block", "uuid": u, "subject": "y", "right": "no"}]))
    assert len(out) == 1 and out[0]["right"] == "yes", out
    out = check(t, json.dumps([{"kind": "circle", "uuid": u, "subject": "s", "event": "first"}, {"kind": "circle", "uuid": u, "subject": "s", "event": "second"}]))
    assert len(out) == 1 and out[0]["event"] == "first", out


# --- the kinds list and the prompt
def test_refs_kinds_and_prompt():
    kinds_md = (SCRIPT.parent.parent / "references/findings-kinds.md").read_text()
    for k in ("hook_block", "guard_block", "user_rejected", "hook_failed", "repeated_call", "reread", "undo_redo", "circle",
              "misunderstood_request", "wrong_approach"):
        assert f"`{k}`" in kinds_md, k
    prompt = (SCRIPT.parent.parent / "references/findings-prompt.md").read_text()
    for w in ("`right`", "`unknown`", "`avoidable`", "unseen", "no tool", "JSON", "quotes what the user said", "why you read it"):
        assert w in prompt, w


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
