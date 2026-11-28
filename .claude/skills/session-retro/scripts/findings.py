"""Find the candidates of a session retro in a transcript, and check the model's findings.

Usage:
  findings.py scan <transcript.jsonl>               candidate groups, as JSON
  findings.py prompt <transcript.jsonl>             the prompt for the fork, with kinds and candidates
  findings.py check <transcript.jsonl> <reply.txt>  the findings to write, as JSON

A candidate group has kind, subject, count, the uuid and evidence of its first event,
and unseen when it is before the last compaction.
"""
import hashlib, json, re, sys
from pathlib import Path

REFS = Path(__file__).resolve().parent.parent / "references"
GUARDS = ("This session is isolated in the worktree",
          "Permission for this action was denied by the Claude Code auto mode classifier")
HOOK_DENY = re.compile(r"^(PreToolUse|PermissionRequest):\w+ hook error")
REJECTED = "doesn't want to proceed"
INTERRUPT = "[Request interrupted by user"
CHANGES = ("Edit", "Write", "MultiEdit", "NotebookEdit")


BLOCKS = {"hook_block", "hook_stop_block", "guard_block", "user_rejected", "hook_failed"}


def entries(path):
    for line in Path(path).read_text(errors="replace").splitlines():
        try:
            o = json.loads(line)
        except ValueError:
            continue
        if isinstance(o, dict) and not o.get("isSidechain"):
            yield o


def script_of(cmd):
    m = re.search(r"([\w.-]+\.(?:sh|py|js))", cmd or "")
    return m.group(1) if m else (cmd or "?").split()[0][:60]


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(text_of(c.get("text") or c.get("content")) for c in content if isinstance(c, dict))
    return ""


def kinds():
    return re.findall(r"^\| `(\w+)` \|", (REFS / "findings-kinds.md").read_text(), re.M)


def scan(path):
    groups, order = {}, []
    seen_calls, last_change, errored, reads, edits = {}, -1, set(), {}, []
    replied = False
    compactions = 0

    def add(kind, subject, uuid, evidence):
        key = (kind, subject)
        if key not in groups:
            groups[key] = {"kind": kind, "subject": subject, "count": 0, "uuid": uuid,
                           "evidence": (evidence or "")[:300], "compaction": compactions}
            order.append(key)
        groups[key]["count"] += 1
        groups[key]["compaction"] = compactions  # unseen only if its last event is before the last compaction

    for i, o in enumerate(entries(path)):
        uuid, t = o.get("uuid", ""), o.get("type")
        if t == "system" and o.get("subtype") == "compact_boundary":
            compactions += 1
        elif t == "attachment":
            a = o.get("attachment") or {}
            if a.get("type") == "hook_blocking_error":
                b = a.get("blockingError") or {}
                stop = (a.get("hookEvent") or a.get("hookName") or "").startswith(("Stop", "SubagentStop"))
                add("hook_stop_block" if stop else "hook_block", script_of(b.get("command")), uuid, b.get("blockingError"))
            elif a.get("type") == "hook_non_blocking_error":
                add("hook_failed", script_of(a.get("command")), uuid, a.get("stderr") or a.get("content"))
        elif t == "assistant":
            for p in (o.get("message") or {}).get("content") or []:
                if not isinstance(p, dict):
                    continue
                if p.get("type") == "text":
                    replied = True
                if p.get("type") != "tool_use":
                    continue
                name, inp = p.get("name", ""), p.get("input") or {}
                key = name + json.dumps(inp, sort_keys=True)
                path_ = inp.get("file_path")
                prev = seen_calls.get(key)
                if prev is not None and prev[0] > last_change and prev[1] not in errored:
                    add("repeated_call", f"{name} {json.dumps(inp, sort_keys=True)[:80]}", uuid, key[:300])
                elif name == "Read" and path_ and reads.get(path_) == "read":
                    add("reread", path_, uuid, path_)
                seen_calls[key] = (i, p.get("id"))
                if name == "Read" and path_:
                    reads[path_] = "read"
                if name in CHANGES:
                    last_change = i
                    if path_:
                        reads[path_] = "changed"
                    if name == "Edit" and path_:
                        if (path_, inp.get("new_string"), inp.get("old_string")) in edits:
                            add("undo_redo", path_, uuid, path_)
                        edits.append((path_, inp.get("old_string"), inp.get("new_string")))
        elif t == "user":
            content = (o.get("message") or {}).get("content")
            if isinstance(content, list) and any(isinstance(c, dict) and c.get("type") == "tool_result" for c in content):
                for c in content:
                    if not isinstance(c, dict) or c.get("type") != "tool_result":
                        continue
                    body = text_of(c.get("content"))
                    if c.get("is_error"):
                        errored.add(c.get("tool_use_id"))
                    guard = next((g for g in GUARDS if body.startswith(g)), None)
                    if guard:
                        add("guard_block", guard, uuid, body)
                    elif HOOK_DENY.match(body):
                        add("hook_block", script_of(body), uuid, body)
                    elif REJECTED in body[:300]:
                        tool = next((n for k, (j, tid) in seen_calls.items() if tid == c.get("tool_use_id") for n in [k.split("{")[0]]), "?")
                        add("user_rejected", tool, uuid, body)
                continue
            body = text_of(content)
            if body.startswith(INTERRUPT):
                add("interrupt", "interrupt", uuid, body)
            elif body.strip() and replied and not o.get("isMeta") and not body.startswith("<"):
                add("user_turn", uuid, uuid, body)
    out = []
    for key in order:
        g = groups.pop(key)
        if g.pop("compaction") < compactions:
            g["unseen"] = True
        out.append(g)
    return out


def prompt(path):
    cands = scan(path)
    text = (REFS / "findings-prompt.md").read_text()
    return text.replace("{kinds}", (REFS / "findings-kinds.md").read_text()).replace("{candidates}", json.dumps(cands, indent=1))


def reply_list(text):
    """The first JSON list in the model's reply."""
    for m in re.finditer(r"\[", text):
        try:
            v, _ = json.JSONDecoder().raw_decode(text[m.start():])
        except ValueError:
            continue
        if isinstance(v, list):
            return v
    raise SystemExit("findings.py check: the reply holds no JSON list")


def check(path, reply):
    uuids = {o.get("uuid") for o in entries(path)}
    by_key = {(c["uuid"], c["kind"]): c for c in scan(path)}
    allowed = set(kinds())
    out, ids = [], set()
    for f in reply_list(Path(reply).read_text()):
        if not isinstance(f, dict) or f.get("kind") not in allowed or f.get("uuid") not in uuids:
            continue
        cand = by_key.get((f["uuid"], f["kind"]))
        f["unseen"] = bool(cand and cand.get("unseen"))  # the scan's flag, never the fork's
        if f["unseen"] and f["kind"] in BLOCKS:
            f["right"] = "unknown"
        if cand:
            f["subject"], f["count"] = cand["subject"], cand["count"]
            key = f"{f['kind']}|{f['subject']}"
        else:
            f.setdefault("count", 1)
            key = f"{f['kind']}|{f['uuid']}|{f.get('subject', '')}"
        f.pop("status", None)
        f["id"] = "F-" + hashlib.sha1(key.encode()).hexdigest()[:8]
        if f["id"] not in ids:  # the first finding of an ID stays
            ids.add(f["id"])
            out.append(f)
    return out


def main(argv):
    if len(argv) == 3 and argv[1] == "scan":
        print(json.dumps(scan(argv[2]), indent=1))
    elif len(argv) == 3 and argv[1] == "prompt":
        print(prompt(argv[2]))
    elif len(argv) == 4 and argv[1] == "check":
        print(json.dumps(check(argv[2], argv[3]), indent=1))
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
