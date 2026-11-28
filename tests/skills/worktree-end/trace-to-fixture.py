#!/usr/bin/env python3
"""Materialise ITF trace states as fixture directories holding one state.json each.

Same point as research-artifacts/tests/trace-to-fixture.py: check-state.sh's
test cases are NOT authored by anyone reading the model — they are
states the Quint simulator or Apalache actually explored, written to disk
mechanically. A checker built from a human (or model) reading of the
specification verifies that reading, not the specification.

Usage:
    trace-to-fixture.py <trace.itf.json> <outdir>

Writes <outdir>/state-<i>/state.json, one directory per state in the trace,
holding exactly the nine model variables (phase, hasCommits, pushed, inSync,
merged, removed, kept, onDefault, discardConfirmed) as plain JSON.
"""

import json
import pathlib
import sys


def unwrap(v):
    """ITF encodes integers as {'#bigint': '19'}; everything else is plain JSON."""
    if isinstance(v, dict) and "#bigint" in v:
        return int(v["#bigint"])
    if isinstance(v, list):
        return [unwrap(x) for x in v]
    return v


VARS = ["phase", "hasCommits", "pushed", "inSync", "merged", "removed", "kept", "onDefault", "discardConfirmed"]


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    trace = json.load(open(sys.argv[1]))
    outdir = pathlib.Path(sys.argv[2])

    for i, state in enumerate(trace["states"]):
        state = {k: v for k, v in state.items() if not k.startswith("#")}
        d = outdir / f"state-{i}"
        d.mkdir(parents=True, exist_ok=True)
        record = {k: unwrap(state[k]) for k in VARS if k in state}
        (d / "state.json").write_text(json.dumps(record, indent=2))
        print(f"state-{i}\t{record}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
