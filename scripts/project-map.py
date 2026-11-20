#!/usr/bin/env python3
"""Look up the project map: which folder is which project.

  project-map.py folders <project>   each folder of the project, one per line
  project-map.py project <path>      the project of the folder that holds the path,
                                     else the last folder name of the path
  project-map.py check <path>        quiet when a folder of the map holds the path,
                                     else "not on the map: <path>" and exit 1
  project-map.py list                each project with its folders

The map is the first Markdown table with a Project and a Folder column in
$PROJECT_MAP, else projects-mapping.md in the main checkout of this harness.
Git ignores that file; projects-mapping.md.template is its start.
Plan: plans/global/components/multi-folder/components/project-map/.
"""
import os
import subprocess
import sys


def default_map():
    """projects-mapping.md in the main checkout of the repo that holds this script."""
    here = os.path.dirname(os.path.realpath(__file__))
    try:
        common = subprocess.run(["git", "-C", here, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True, check=True).stdout.strip()
        root = os.path.dirname(common)
    except (OSError, subprocess.CalledProcessError):
        root = os.path.dirname(here)
    return os.path.join(root, "projects-mapping.md")


def map_path():
    return os.path.expanduser(os.environ.get("PROJECT_MAP") or default_map())


def read_rows(path):
    """Rows of the first table with Project and Folder headers: [(project, folder)]."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        return None
    rows, cols = [], None
    for line in lines:
        cells = [c.strip() for c in line.strip().strip("|").split("|")] if line.lstrip().startswith("|") else None
        if cols is None:
            if cells and "Project" in cells and "Folder" in cells:
                cols = (cells.index("Project"), cells.index("Folder"))
            continue
        if cells is None:
            break
        if all(set(c) <= set("-: ") for c in cells) or len(cells) <= max(cols):
            continue
        project, folder = cells[cols[0]], cells[cols[1]].strip("`")
        if project and folder:
            rows.append((project, os.path.expanduser(folder).rstrip("/") or "/"))
    return rows if cols else None


def holds(folder, path):
    return path == folder or path.startswith(folder + "/")


def project_of(rows, path):
    """The project of the longest folder that is the path or holds it, else None."""
    forms = {os.path.abspath(path).rstrip("/") or "/", os.path.realpath(path).rstrip("/") or "/"}
    best = None
    for project, folder in rows:
        for f in {folder, os.path.realpath(folder)}:
            if any(holds(f, p) for p in forms) and (best is None or len(f) > len(best[1])):
                best = (project, f)
    return best[0] if best else None


def projects(rows):
    return list(dict.fromkeys(p for p, _ in rows))


def main(argv):
    if len(argv) < 2 or argv[1] not in ("folders", "project", "check", "list") or (argv[1] != "list" and len(argv) != 3):
        print(__doc__.strip(), file=sys.stderr)
        return 64
    path = map_path()
    rows = read_rows(path)
    if rows is None:
        print(f"no project map: {path}", file=sys.stderr)
        return 2
    kind = argv[1]
    if kind == "list":
        for p in projects(rows):
            print(f"{p}: " + " ".join(f for q, f in rows if q == p))
        return 0
    arg = argv[2]
    if kind == "folders":
        found = [f for p, f in rows if p == arg]
        if not found:
            print(f"unknown project: {arg}", file=sys.stderr)
            print("\n".join(projects(rows)))
            return 1
        print("\n".join(found))
        return 0
    if kind == "check":
        if project_of(rows, arg):
            return 0
        print(f"not on the map: {arg}", file=sys.stderr)
        return 1
    print(project_of(rows, arg) or folder_name(arg))
    return 0


def folder_name(path):
    """The last folder name of the path, or of the folder that holds a file."""
    full = os.path.abspath(path)
    if os.path.isfile(full):
        full = os.path.dirname(full)
    return os.path.basename(full) or full


if __name__ == "__main__":
    sys.exit(main(sys.argv))
