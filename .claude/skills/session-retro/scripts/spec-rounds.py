#!/usr/bin/env python3
"""The spec rounds of one session: rows in spec-rounds.csv and a Spec section on its retro page.

Usage: spec-rounds.py record <session_id> <transcript> <page>

A round ends at each Bash call that commits an "[automatic after <skill>] <level>:" message
and does not fail. It runs from the end of the round before, or from the start of the session.
The rows of the session take the place of its old rows in
$SESSION_RETRO_KB/claude-research/session-retro/spec-rounds.csv. The page gets one "## Spec"
section: the median per round of this session next to the median of all rows, with "worse"
where this session is above it. A session with no round gets nothing, and the script prints
"skipped for now: no spec round". It exits 1 and writes nothing when it cannot read the transcript.
"""
import csv, io, json, os, re, statistics, sys
from collections import Counter
from datetime import datetime
from pathlib import Path

KB = Path(os.environ.get("SESSION_RETRO_KB") or Path.home() / "second-brain/personal")
CSV = KB / "claude-research/session-retro/spec-rounds.csv"
COLUMNS = ["session", "level", "step", "end", "claude_min", "wait_min", "model_min", "tool_min", "subagents",
           "subagent_min", "turns", "hook_blocks", "hook_blocks_by_hook", "failed_checks", "rejected_tools",
           "interrupts", "p_status", "p_confused", "p_continue", "p_skip_checks", "source"]
# The rows of the Spec section. In each one, more is worse.
METRICS = [("Claude minutes", "claude_min"), ("Minutes waiting on you", "wait_min"), ("Subagents", "subagents"),
           ("Hook blocks", "hook_blocks"), ("Failed checks", "failed_checks"),
           ("Rejected tool calls", "rejected_tools"), ("Interrupts", "interrupts"),
           ("Status prompts", "p_status"), ("Confused prompts", "p_confused"),
           ("Continue prompts", "p_continue"), ("Skip-check prompts", "p_skip_checks")]
COMMIT = re.compile(r"\[automatic after ([a-z-]+)\] ([^\s:\"'\\]+):")
GIT_COMMIT = re.compile(r"(^|[;&|(]\s*)git(\s+-[cC]\s+\S+)*\s+commit\b", re.M)
CHECK = re.compile(r"-check\.py|check-[a-z-]+\.sh|--test|tests?/|test-[a-z-]+\.(sh|py)|node --test|quint (test|run|verify)|npm run check")
KINDS = {
    "p_status": re.compile(r"all (built|done|good|fixed|synced)|ready to merge|what is left|what now|what is next|good to merge|still running|what is this session", re.I),
    "p_confused": re.compile(r"what does (this|that|it) mean|don.?t (understand|udnerstand)|\bwtf\b|not sure i get|idk what|^what\?", re.I),
    "p_continue": re.compile(r"^\s*(continue|go|go on|yes|yeah continue|keep going|sure)\W*$", re.I),
    "p_skip_checks": re.compile(r"skip (the )?(quint|model|review|all the check)|without the verify", re.I),
}
REJECTED = "doesn't want to proceed"
# The hook of a block whose text does not start with its name.
HOOK_PHRASES = [("the graph breaks", "draw-graph"), ("Check whether 1-design.md", "design-pair"),
                ("Mermaid", "no-mermaid"), ("not in the layout", "plan-layout")]


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()


def load(path):
    recs, seen = [], set()
    for line in open(path, errors="replace"):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if not d.get("timestamp") or d.get("isSidechain") or d.get("uuid") in seen:
            continue
        seen.add(d.get("uuid"))
        d["_t"] = ts(d["timestamp"])
        recs.append(d)
    return sorted(recs, key=lambda d: d["_t"])


def blocks_of(d):
    """The content blocks of a record, as a list."""
    c = (d.get("message") or {}).get("content")
    return c if isinstance(c, list) else []


def commits(recs):
    """(time, step, level) of each automatic plan commit that did not fail."""
    calls, out = {}, []
    for d in recs:
        for b in blocks_of(d):
            if not isinstance(b, dict):
                continue
            if d["type"] == "assistant" and b.get("type") == "tool_use" and b.get("name") == "Bash":
                cmd = (b.get("input") or {}).get("command", "")
                m = COMMIT.search(cmd)
                if m and GIT_COMMIT.search(cmd):
                    calls[b["id"]] = (m.group(1), m.group(2))
            elif b.get("type") == "tool_result" and b.get("tool_use_id") in calls and not b.get("is_error"):
                step, level = calls.pop(b["tool_use_id"])
                out.append((d["_t"], step, level))
    return out


def prompt_text(d):
    c = (d.get("message") or {}).get("content")
    if d["type"] != "user" or d.get("isMeta") or not isinstance(c, str):
        return None
    return re.sub(r"<[^>]+>", " ", c).strip()


def measure(recs, start, end):
    """The numbers of one round: the records after start, up to and with end."""
    win = [d for d in recs if start < d["_t"] <= end]
    calls, n = {}, Counter()
    hooks, mids, last = Counter(), set(), start
    for d in recs:
        if d.get("type") == "system" and d.get("subtype") == "turn_duration":
            a, b = d["_t"] - d.get("durationMs", 0) / 1000, d["_t"]
            n["claude_s"] += max(0, min(b, end) - max(a, start))
    for d in win:
        a = d.get("attachment") or {}
        if a.get("type") == "hook_blocking_error":
            hooks[hook_name(a)] += 1
        if d["type"] == "assistant":
            mid = (d.get("message") or {}).get("id")
            if mid not in mids:
                mids.add(mid)
                n["model_s"] += min(d["_t"] - last, 900)
            for b in blocks_of(d):
                if isinstance(b, dict) and b.get("type") == "tool_use":
                    calls[b["id"]] = (d["_t"], b.get("name"), (b.get("input") or {}).get("command", ""))
                    if b.get("name") == "Agent":
                        n["subagents"] += 1
        elif d["type"] == "user":
            c = (d.get("message") or {}).get("content")
            text = prompt_text(d)
            if text:
                for k, rx in KINDS.items():
                    n[k] += bool(rx.search(text))
            for b in blocks_of(d):
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "text" and b.get("text", "").startswith("[Request interrupted by user"):
                    n["interrupts"] += 1
                if b.get("type") == "tool_result" and b.get("tool_use_id") in calls:
                    t0, name, cmd = calls[b["tool_use_id"]]
                    took = d["_t"] - t0
                    key = {"AskUserQuestion": "wait_s", "Agent": "subagent_s"}.get(name, "tool_s")
                    n[key] += took
                    if REJECTED in json.dumps(b.get("content", "")):
                        n["rejected_tools"] += 1
                    elif b.get("is_error") and name == "Bash" and CHECK.search(cmd):
                        n["failed_checks"] += 1
        last = d["_t"]
    mins = lambda s: round(s / 60, 1)
    return {"claude_min": mins(n["claude_s"]), "wait_min": mins(n["wait_s"]), "model_min": mins(n["model_s"]),
            "tool_min": mins(n["tool_s"]), "subagents": n["subagents"], "subagent_min": mins(n["subagent_s"]),
            "turns": len(mids), "hook_blocks": sum(hooks.values()),
            "hook_blocks_by_hook": ";".join(f"{h}:{c}" for h, c in sorted(hooks.items())),
            "failed_checks": n["failed_checks"], "rejected_tools": n["rejected_tools"], "interrupts": n["interrupts"],
            **{k: n[k] for k in KINDS}}


def hook_name(a):
    """<event>/<hook> of a hook block: the script of its command, else the first word of its text,
    else a phrase of its text. Claude Code names an inline hook only "command hook <n>"."""
    err = a.get("blockingError") or {}
    cmd = str(err.get("command") or "")
    text = str(err.get("blockingError", ""))
    name = Path(cmd.split()[0]).stem if cmd.strip() and not cmd.startswith("command hook") else ""
    head = text.split(":", 1)[0].strip()
    if not name and re.fullmatch(r"[\w.-]+", head):
        name = head
    if not name:
        name = next((n for phrase, n in HOOK_PHRASES if phrase in text), "?")
    return f"{a.get('hookEvent') or a.get('hookName') or '?'}/{name}"


def rounds(sid, recs, source="retro"):
    rows, prev = [], (recs[0]["_t"] - 1 if recs else 0)
    for end, step, level in commits(recs):
        row = {"session": sid[:8], "level": level, "step": step,
               "end": datetime.fromtimestamp(end).astimezone().isoformat(timespec="minutes"),
               **measure(recs, prev, end), "source": source}
        rows.append(row)
        prev = end
    return rows


def read_csv():
    return list(csv.DictReader(CSV.open())) if CSV.exists() else []


def csv_text(rows):
    out = io.StringIO()
    w = csv.DictWriter(out, fieldnames=COLUMNS, extrasaction="ignore")
    w.writeheader()
    w.writerows(sorted(rows, key=lambda r: (r["end"], r["session"])))
    return out.getvalue()


def med(rows, key):
    vals = [float(r[key]) for r in rows if str(r.get(key, "")) != ""]
    return statistics.median(vals) if vals else None


def fmt(x):
    return "" if x is None else (str(int(x)) if float(x).is_integer() else f"{x:.1f}")


def section(mine, every):
    levels = ", ".join(sorted({r["level"] for r in mine}))
    lines = ["## Spec", "",
             f"Rounds: {len(mine)}. Levels: {levels}.", "",
             f"Each number is the median per round. `worse` marks a number above the median of all {len(every)} rows "
             "of `spec-rounds.csv`.", "",
             "| Metric | This session | All rows | |", "|---|---|---|---|"]
    for label, key in METRICS:
        a, b = med(mine, key), med(every, key)
        worse = "worse" if a is not None and b is not None and a > b else ""
        lines.append(f"| {label} | {fmt(a)} | {fmt(b)} | {worse} |")
    hooks = Counter()
    for r in mine:
        for part in filter(None, str(r["hook_blocks_by_hook"]).split(";")):
            h, c = part.rsplit(":", 1)
            hooks[h] += int(c)
    if hooks:
        lines += ["", "Hook blocks by hook: " + ", ".join(f"`{h}` {c}" for h, c in hooks.most_common()) + "."]
    return "\n".join(lines) + "\n"


def put_section(text, sec):
    m = re.search(r"^## Spec\n.*?(?=^## |\Z)", text, re.M | re.S)
    if m:
        return text[:m.start()] + sec + ("\n" if text[m.end():] else "") + text[m.end():]
    return text.rstrip("\n") + "\n\n" + sec


def write(files):
    """Write each (path, text) to a temp file first, then rename them all, so a failed write changes nothing."""
    tmps = []
    try:
        for path, text in files:
            tmp = path.with_name(path.name + ".tmp")
            tmp.write_text(text)
            tmps.append((tmp, path))
    except OSError:
        for tmp, _ in tmps:
            tmp.unlink(missing_ok=True)
        raise
    for tmp, path in tmps:
        tmp.replace(path)


def record(sid, transcript, page):
    try:
        recs = load(transcript)
    except OSError as e:
        print(f"no transcript: {e}", file=sys.stderr)
        return 1
    mine = rounds(sid, recs)
    if not mine:
        print("skipped for now: no spec round")
        return 0
    every = [r for r in read_csv() if r["session"] != sid[:8]] + mine
    page = Path(page)
    text = put_section(page.read_text(), section(mine, every))
    CSV.parent.mkdir(parents=True, exist_ok=True)
    write([(CSV, csv_text(every)), (page, text)])
    print(f"{len(mine)} rounds")
    return 0


def main(argv):
    if len(argv) == 5 and argv[1] == "record":
        return record(*argv[2:])
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
