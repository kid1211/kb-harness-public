"""Unit tests of spec-rounds.py. Cases follow the runs and invariants of spec-rounds.qnt.

Run: python3 -I tests/skills/session-retro/test-spec-rounds.py [name] [--script <path>]
A name runs only the tests whose name holds it. --script runs them on a broken copy, for a fixture run.
"""
import csv, json, os, subprocess, sys, tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / ".claude/skills/session-retro/scripts/spec-rounds.py"
SID = "abcdef12-3456-7890-abcd-ef1234567890"
T0 = datetime(2026, 11, 28, 15, 0, tzinfo=timezone.utc)


class Transcript:
    """A made-up transcript: each call adds records, a minute after the one before."""

    def __init__(self):
        self.recs, self.t, self.n = [], T0, 0

    def _add(self, rec, minutes=1):
        self.t += timedelta(minutes=minutes)
        self.n += 1
        rec.update(uuid=f"u{self.n}", timestamp=self.t.isoformat().replace("+00:00", "Z"), sessionId=SID)
        self.recs.append(rec)

    def prompt(self, text):
        self._add({"type": "user", "message": {"role": "user", "content": text}})

    def tool(self, name, inp, result="ok", error=False, minutes=1):
        self.n += 1
        tid = f"t{self.n}"
        self._add({"type": "assistant", "message": {"id": f"m{self.n}", "role": "assistant",
                   "content": [{"type": "tool_use", "id": tid, "name": name, "input": inp}]}})
        self._add({"type": "user", "message": {"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": tid, "content": result, "is_error": error}]}}, minutes)

    def turn(self, ms):
        self._add({"type": "system", "subtype": "turn_duration", "durationMs": ms}, 0)

    def block(self, hook, event="Stop"):
        """A hook block, as Claude Code writes it: an attachment, and for a Stop hook a feedback prompt too."""
        self._add({"type": "attachment", "attachment": {"type": "hook_blocking_error", "hookName": event,
                   "hookEvent": event, "blockingError": {"blockingError": f"{hook}: the text breaks a rule.",
                   "command": f".claude/hooks/{hook}.py"}}})
        if event == "Stop":
            self._add({"type": "user", "isMeta": True, "message": {"role": "user",
                       "content": f"Stop hook feedback:\n{hook}: the text breaks a rule."}}, 0)

    def commit(self, skill, level):
        self.tool("Bash", {"command": f'git commit -m "[automatic after {skill}] {level}: a round"'})

    def write(self, path):
        path.write_text("".join(json.dumps(r) + "\n" for r in self.recs))
        return path


def two_rounds():
    t = Transcript()
    t.prompt("/spec add a thing")
    t.tool("Agent", {"prompt": "review"}, minutes=3)
    t.block("writing-check")
    t.block("draw-graph", event="PostToolUse")
    t.tool("Bash", {"command": "python3 -I x-check.py --test"}, result="FAIL", error=True)
    t.tool("Edit", {"file_path": "a"}, result="The user doesn't want to proceed with this tool use.")
    t.prompt("so all built?")
    t.turn(240000)
    t.commit("p-req", "plans/demo")
    t.prompt("what does that mean?")
    t.prompt("go")
    t.tool("AskUserQuestion", {"questions": []}, minutes=5)
    t.prompt("skip the quint verify")
    t._add({"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": "[Request interrupted by user]"}]}})
    t.commit("p-build", "plans/demo")
    return t


class Env:
    def __init__(self, script=SCRIPT):
        self.tmp = Path(tempfile.mkdtemp())
        self.kb = self.tmp / "kb"
        self.dir = self.kb / "claude-research/session-retro"
        self.dir.mkdir(parents=True)
        self.csv = self.dir / "spec-rounds.csv"
        self.page = self.dir / "2026-11-28-abcdef12.staging.md"
        self.page.write_text("# Session retro\n\n## Findings\n\nNo findings.\n")
        self.script = script
        self.env = {**os.environ, "SESSION_RETRO_KB": str(self.kb)}

    def record(self, transcript, sid=SID):
        path = transcript.write(self.tmp / "t.jsonl") if isinstance(transcript, Transcript) else transcript
        return subprocess.run([sys.executable, "-I", str(self.script), "record", sid, str(path), str(self.page)],
                              capture_output=True, text=True, env=self.env)

    def rows(self, sid=SID[:8]):
        if not self.csv.exists():
            return []
        return [r for r in csv.DictReader(self.csv.open()) if r["session"] == sid]


TESTS = []


def test(f):
    TESTS.append(f)
    return f


@test
def two_rounds_give_two_rows_with_counts():
    """recordedTest, writeRows, oneRowPerRound: one row per round, each count right, a Spec section."""
    e = Env(SCRIPT_UNDER_TEST)
    r = e.record(two_rounds())
    assert r.returncode == 0, r.stderr
    rows = e.rows()
    assert len(rows) == 2, rows
    a, b = rows
    assert (a["level"], a["step"], b["step"]) == ("plans/demo", "p-req", "p-build"), rows
    assert a["subagents"] == "1" and float(a["subagent_min"]) == 3.0, a
    assert a["hook_blocks"] == "2" and a["hook_blocks_by_hook"] == "PostToolUse/draw-graph:1;Stop/writing-check:1", a
    assert a["failed_checks"] == "1" and a["rejected_tools"] == "1", a
    assert a["p_status"] == "1" and a["p_confused"] == "0", a
    assert float(a["claude_min"]) == 4.0, a
    assert b["p_confused"] == "1" and b["p_continue"] == "1" and b["p_skip_checks"] == "1", b
    assert b["interrupts"] == "1" and float(b["wait_min"]) == 5.0, b
    assert int(a["turns"]) > 0 and a["source"] == "retro", a
    assert e.page.read_text().count("## Spec") == 1


@test
def run_again_keeps_one_row_per_round():
    """againTest, oneRowPerRound: a run again gives the same rows and one section."""
    e = Env(SCRIPT_UNDER_TEST)
    t = two_rounds()
    e.record(t)
    r = e.record(t)
    assert r.returncode == 0, r.stderr
    assert len(e.rows()) == 2
    assert e.page.read_text().count("## Spec") == 1


@test
def other_session_rows_stay():
    """otherRowsKept: the rows of another session never go away."""
    e = Env(SCRIPT_UNDER_TEST)
    e.record(two_rounds(), sid="99999999-0000-0000-0000-0000000000aa")
    e.record(two_rounds())
    assert len(e.rows("99999999")) == 2 and len(e.rows()) == 2


@test
def no_round_no_row_no_section():
    """skippedTest, skip, sectionIffRounds: a session with no automatic plan commit gets nothing."""
    e = Env(SCRIPT_UNDER_TEST)
    t = Transcript()
    t.prompt("hello")
    r = e.record(t)
    assert r.returncode == 0, r.stderr
    assert "skipped for now: no spec round" in r.stdout
    assert e.rows() == [] and "## Spec" not in e.page.read_text()


@test
def no_transcript_fails_and_writes_nothing():
    """failedTest, noTranscript: exit 1, nothing written."""
    e = Env(SCRIPT_UNDER_TEST)
    r = e.record(e.tmp / "missing.jsonl")
    assert r.returncode == 1
    assert not e.csv.exists() and "## Spec" not in e.page.read_text()


@test
def worse_mark_only_above_median():
    """F4: `worse` only where this session is above the median of all rows."""
    e = Env(SCRIPT_UNDER_TEST)
    quiet = Transcript()
    quiet.prompt("/spec")
    quiet.commit("p-req", "plans/demo")
    for sid in ("11111111-0", "22222222-0", "33333333-0"):
        e.record(quiet, sid=sid)
    e.record(two_rounds())
    text = e.page.read_text()
    line = next(l for l in text.splitlines() if l.startswith("| Hook blocks"))
    assert line.rstrip().endswith("worse |"), line
    line = next(l for l in text.splitlines() if l.startswith("| Minutes waiting on you"))
    assert "worse" in line, line


@test
def section_has_rows_of_its_session():
    """sectionHasRows: a page with a Spec section has rows of its session."""
    e = Env(SCRIPT_UNDER_TEST)
    e.record(two_rounds())
    assert "## Spec" in e.page.read_text() and e.rows()


@test
def only_a_real_commit_with_a_level_ends_a_round():
    """scanTo: a commit with no `<level>:`, a git log, a heredoc and a failed commit end no round."""
    e = Env(SCRIPT_UNDER_TEST)
    t = Transcript()
    t.prompt("/spec")
    t.tool("Bash", {"command": 'git commit -m "[automatic after p-research] found three answers"'})
    t.tool("Bash", {"command": 'git log --grep="[automatic after p-req] plans/demo:" --format=commit'})
    t.tool("Bash", {"command": "cat > f.py <<'EOF'\nmsg = 'commit [automatic after p-req] plans/demo: x'\nEOF"})
    t.tool("Bash", {"command": 'git commit -m "[automatic after p-req] plans/demo: x"'}, result="hook refused", error=True)
    t.commit("p-design", "plans/demo")
    t.commit("p-build", "plans/demo")
    r = e.record(t)
    assert r.returncode == 0, r.stderr
    assert [x["step"] for x in e.rows()] == ["p-design", "p-build"], e.rows()


SCRIPT_UNDER_TEST = SCRIPT


def main(argv):
    global SCRIPT_UNDER_TEST
    if "--script" in argv:
        i = argv.index("--script")
        SCRIPT_UNDER_TEST = Path(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    name = argv[1] if len(argv) > 1 else ""
    failed = 0
    for f in TESTS:
        if name not in f.__name__:
            continue
        try:
            f()
            print("ok  ", f.__name__)
        except Exception as ex:
            failed += 1
            print("FAIL", f.__name__, "-", type(ex).__name__, ex)
    print("all pass" if not failed else f"{failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
