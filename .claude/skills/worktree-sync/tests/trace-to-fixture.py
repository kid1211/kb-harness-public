#!/usr/bin/env python3
"""Materialise an ITF trace state as a config file naming one outcome bucket.

worktree-sync's model (../model.qnt) is a configuration model over
{isWorktree, isClean, fetchOk, conflict} -> outcome. Quint has no notion of
git, so it cannot materialise a repository directly — but it does choose
*which combination of booleans* to explore, via `quint verify`'s counterexample
search on a deliberately-false witness invariant. That choice is what this
script writes to disk; test-worktree-sync.sh reads it back and does the git
plumbing that realizes it as an actual repository.

Usage:
    trace-to-fixture.py <trace.itf.json> <outdir>

Writes <outdir>/state-<i>/config.env, one directory per state in the trace,
each holding shell-sourceable ISWORKTREE=/ISCLEAN=/FETCHOK=/CONFLICT=/OUTCOME=
assignments read straight off that state.
"""

import json
import pathlib
import sys


def unwrap(v):
    """ITF encodes integers as {'#bigint': '19'}."""
    if isinstance(v, dict) and "#bigint" in v:
        return int(v["#bigint"])
    return v


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
        cfg = {
            "ISWORKTREE": unwrap(state["isWorktree"]),
            "ISCLEAN": unwrap(state["isClean"]),
            "FETCHOK": unwrap(state["fetchOk"]),
            "CONFLICT": unwrap(state["conflict"]),
            "OUTCOME": unwrap(state["outcome"]),
        }
        (d / "config.env").write_text(
            "\n".join(f"{k}={v}" for k, v in cfg.items()) + "\n"
        )
        print(f"state-{i}\t" + " ".join(f"{k}={v}" for k, v in cfg.items()))

    return 0


if __name__ == "__main__":
    sys.exit(main())
