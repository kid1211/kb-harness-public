#!/usr/bin/env python3
"""The context of each folder from the project map: its project, its role, and the
supporting docs of its project, the folders of the project its KB column names.

  folder-context.py <folder>...          one or two lines per folder, for Claude
  folder-context.py --json <folder>...   the same as a JSON array, for the folder pane

The map is the one scripts/project-map.py reads.
Plan: plans/global/components/multi-folder/components/add-dir-context/.
"""
import importlib.util
import json
import os
import sys

spec = importlib.util.spec_from_file_location("project_map", os.path.join(os.path.dirname(os.path.abspath(__file__)), "project-map.py"))
pm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pm)


def read_table(path):
    """Each row of the map's first Project and Folder table, as a dict by header."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return []
    head, rows = None, []
    for line in lines:
        if not line.lstrip().startswith("|"):
            if head:
                break
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if head is None:
            if "Project" in cells and "Folder" in cells:
                head = cells
        elif not all(set(c) <= set("-: ") for c in cells) and len(cells) >= len(head):
            r = dict(zip(head, cells))
            r["Folder"] = os.path.expanduser(r["Folder"].strip("`")).rstrip("/") or "/"
            rows.append(r)
    return rows


def context(rows, folder):
    path = os.path.abspath(folder).rstrip("/") or "/"
    project = pm.project_of([(r["Project"], r["Folder"]) for r in rows], path)
    forms = {path, os.path.realpath(path)}
    held = [r for r in rows if r["Project"] == project
            and any(pm.holds(f, p) for f in {r["Folder"], os.path.realpath(r["Folder"])} for p in forms)]
    row = max(held, key=lambda r: len(r["Folder"]), default=None)
    if row is None:
        return {"folder": path, "project": None, "role": None, "docs": []}
    kb = row.get("KB", "")
    docs = [{"folder": r["Folder"], "role": r.get("Role", ""), "project": r["Project"]}
            for r in rows if kb and r["Project"] == kb and r["Folder"] != path]
    return {"folder": path, "project": project, "role": row.get("Role", ""), "docs": docs}


def main(argv):
    as_json = argv[1:2] == ["--json"]
    folders = argv[2:] if as_json else argv[1:]
    if not folders:
        print(__doc__.strip(), file=sys.stderr)
        return 64
    rows = read_table(os.path.expanduser(os.environ.get("PROJECT_MAP") or pm.DEFAULT))
    found = [context(rows, f) for f in folders]
    if as_json:
        print(json.dumps(found))
        return 0
    for c in found:
        if c["project"] is None:
            print(f"Folder {c['folder']}: on no row of the project map.")
            continue
        print(f"Folder {c['folder']}: project {c['project']}, role {c['role']}.")
        if c["docs"]:
            print(f"Supporting docs of {c['project']}: " + ", ".join(f"{d['folder']} ({d['role']})" for d in c["docs"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
