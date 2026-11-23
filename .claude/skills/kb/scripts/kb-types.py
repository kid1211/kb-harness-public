#!/usr/bin/env python3
"""Check the pages of one KB domain against the `## Types` table of its CLAUDE.md, or draw the types.

Usage:
  kb-types.py check <domain>
  kb-types.py draw <domain>
  kb-types.py map [<roots file>]     default: ../assets/kb-roots.txt
  kb-types.py --test

check: a page whose path matches no row is untyped. It is listed, and it is not a
break. Each typed page is tested for its fields, their kinds, its area, its parts
and links, and cycles. Prints `untyped <path>` lines, then one line per break,
`<path>: <type>: <kind>: <what>`, and exits 1, or `ok <domain>` and exits 0.
draw: prints one graph block of the types, as OOP classes.
Both print `skip <domain>: no Types table` and exit 0 for a domain with no table,
and `<CLAUDE.md>: Types row <n>: <what>` with exit 2 for a wrong table.
"""
import json
import os
import re
import sys
import tempfile
from urllib.parse import unquote
from pathlib import Path

KINDS = ("text", "number", "score", "date", "list")
COLUMNS = ("Type", "Is a", "Collection", "Areas", "Made of", "Part fields", "Links to", "Fields")
DAY = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class BadTable(Exception):
    pass


def area(name):
    """The area a file name gives, and the name with its area suffix taken out."""
    bits = name.split(".")
    if len(bits) >= 3 and bits[-2] in ("source", "staging"):
        return bits[-2], ".".join(bits[:-2] + bits[-1:])
    return "consolidated", name


def pattern(coll):
    """A collection such as `meals/<date>.md` as a regex over a path with its area suffix taken out."""
    out = ""
    for tok in re.split(r"(<name>|<date>|\*)", coll):
        out += {"<name>": r"[^/]+", "<date>": r"\d{4}-\d{2}-\d{2}", "*": r"[^/]*"}.get(tok, re.escape(tok))
    return re.compile(out + "$")


def split_list(cell):
    return [x.strip().strip("`").strip() for x in cell.split(",") if x.strip().strip("`").strip()]


def fields(cell, n):
    """`name: kind!` items into {name: (kind, required)}."""
    out = {}
    for item in split_list(cell):
        name, _, kind = item.partition(":")
        kind = kind.strip()
        req = kind.endswith("!")
        kind = kind.rstrip("!").strip()
        if not name.strip() or not (kind in KINDS or kind.startswith("link:")):
            raise BadTable(f"Types row {n}: unknown kind {kind or item}")
        out[name.strip()] = (kind, req)
    return out


def read_table(claude_md):
    """The rows of `## Types` as {type: dict}, in table order, or None with no table."""
    lines = claude_md.read_text().splitlines() if claude_md.exists() else []
    try:
        start = next(i for i, x in enumerate(lines) if x.strip() == "## Types")
    except StopIteration:
        return None
    rows = []
    for x in lines[start + 1:]:
        if x.startswith("#"):
            break
        if x.strip().startswith("|"):
            rows.append([c.strip() for c in x.strip().strip("|").split("|")])
        elif rows:
            break
    if len(rows) < 2:
        return None
    types = {}
    for n, cells in enumerate(rows[2:], 1):
        if len(cells) != len(COLUMNS):
            raise BadTable(f"Types row {n}: {len(cells)} cells, not {len(COLUMNS)}")
        c = dict(zip(COLUMNS, cells))
        name = c["Type"].strip("`")
        types[name] = {"n": n, "parent": c["Is a"].strip("`"), "coll": c["Collection"].strip("`"),
                       "re": pattern(c["Collection"].strip("`")), "areas": set(split_list(c["Areas"])),
                       "made_of": set(split_list(c["Made of"])), "part_fields": fields(c["Part fields"], n),
                       "links_to": set(split_list(c["Links to"])), "fields": fields(c["Fields"], n)}
    for name, t in types.items():
        named = t["made_of"] | t["links_to"] | {t["parent"]} - {""}
        named |= {k[5:] for k, _ in t["fields"].values() if k.startswith("link:")}
        for other in sorted(named):
            if other not in types:
                raise BadTable(f"Types row {t['n']}: unknown type {other}")
        if not t["areas"] <= {"source", "staging", "consolidated"}:
            raise BadTable(f"Types row {t['n']}: unknown area in {sorted(t['areas'])}")
        seen, p = {name}, t["parent"]
        while p:
            if p in seen:
                raise BadTable(f"Types row {t['n']}: is a cycle through {p}")
            seen.add(p)
            p = types[p]["parent"]
    return types


def all_fields(types, name):
    """The fields of a type and of each type it extends; the nearest one wins."""
    out, p = {}, name
    while p:
        out = {**types[p]["fields"], **out}
        p = types[p]["parent"]
    return out


def is_a(types, name, wanted):
    while name:
        if name == wanted:
            return True
        name = types[name]["parent"]
    return False


def frontmatter(path):
    """Flat `key: value` lines and `- ` lists between the first two `---` lines."""
    try:
        lines = path.read_text().splitlines()
    except (UnicodeDecodeError, OSError):
        return {}
    if not lines or lines[0].strip() != "---":
        return {}
    out, key = {}, None
    for x in lines[1:]:
        if x.strip() == "---":
            break
        if x.lstrip().startswith("- ") and key and isinstance(out.get(key), list):
            out[key].append(x.lstrip()[2:].strip())
        elif ":" in x:
            key, _, v = x.partition(":")
            key, v = key.strip(), v.strip()
            out[key] = v.strip('"\'') if v else []
    return out


def kind_ok(kind, v):
    if kind == "list":
        return isinstance(v, list)
    if isinstance(v, list) or v == "":
        return False
    if kind == "number":
        try:
            float(v)
            return True
        except ValueError:
            return False
    if kind == "score":
        return v.isdigit() and 1 <= int(v) <= 5
    if kind == "date":
        return bool(DAY.match(v))
    return True


def type_of(types, rel):
    """The type of the first row whose collection matches the path, with its area suffix taken out."""
    a, name = area(rel.name)
    key = (rel.parent / name).as_posix()
    return next((t for t, row in types.items() if row["re"].match(key)), None), a


RELS = {"part_of": "part of", "made_of": "made of", "links_to": "links to"}
LINK = re.compile(r"\]\(([^)]+)\)")


KEY_LINE = re.compile(r"^- ([A-Za-z][A-Za-z ]*): ")


def key_lines(path):
    """The `- Key: value` lines before the first `##` heading, as snake_case field names."""
    out = set()
    for x in path.read_text(errors="ignore").splitlines():
        if x.startswith("## "):
            break
        m = KEY_LINE.match(x)
        if m:
            out.add(m.group(1).strip().lower().replace(" ", "_"))
    return out


def page_types(domain):
    """The types the pages say in their frontmatter: {type: {parent, fields, rels}}."""
    pages = {p.resolve(): frontmatter(p) for p in Path(domain).rglob("*.md")
             if p.name != "CLAUDE.md" and not any(x.startswith(".") for x in p.relative_to(domain).parts)}
    out = {}
    for p, fm in pages.items():
        t = fm.get("type")
        if not t or not isinstance(t, str):
            continue
        row = out.setdefault(t, {"parent": "", "fields": set(), "rels": set()})
        row["parent"] = row["parent"] or (fm.get("is_a") if isinstance(fm.get("is_a"), str) else "")
        row["fields"] |= (set(fm) | key_lines(p)) - {"type", "is_a"} - set(RELS)
        for key, kind in RELS.items():
            vals = fm.get(key) or []
            for v in [vals] if isinstance(vals, str) else vals:
                m = LINK.search(v)
                ref = unquote((m.group(1) if m else v).split()[0].split("#")[0]) if (m or v.strip()) else ""
                target = pages.get((p.parent / ref).resolve(), {}).get("type") if ref else None
                if isinstance(target, str) and target:
                    row["rels"].add((kind, target))
                else:
                    print(f"{p}: {key} {v}: no typed page", file=sys.stderr)
    return out


def draw_pages(pt):
    """One graph block from page_types: each type with its fields, and its links."""
    node = lambda name: name.replace(" ", "_")
    out = ["```graph"]
    out += [f"{node(t)}: {', '.join(sorted(r['fields']))}" for t, r in sorted(pt.items()) if r["fields"]]
    for t, r in sorted(pt.items()):
        links = ([f"{node(r['parent'])} [is a]"] if r["parent"] else []) + [f"{node(x)} [{k}]" for k, x in sorted(r["rels"])]
        if links:
            out.append(f"{node(t)} -> " + ", ".join(links))
    out.append("```")
    return "\n".join(out)


def run_domain(cmd, domain):
    domain = Path(domain)
    try:
        types = read_table(domain / "CLAUDE.md")
    except BadTable as e:
        print(f"{domain / 'CLAUDE.md'}: {e}")
        return 2
    pt = page_types(domain) if cmd == "draw" else None
    if pt:
        print(draw_pages(pt))
        return 0
    if types is None:
        print(f"skip {domain}: no Types table")
        return 0
    if cmd == "draw":
        print(draw(types))
        return 0
    return check(types, domain)


def check(types, domain):
    objs, untyped = {}, []
    for d, dirs, names in os.walk(domain):
        dirs[:] = sorted(x for x in dirs if not x.startswith("."))
        for n in sorted(names):
            rel = (Path(d) / n).relative_to(domain)
            if rel.as_posix() == "CLAUDE.md" or n.startswith("."):
                continue
            t, a = type_of(types, rel)
            if t is None:
                untyped.append(rel)
            else:
                objs[rel] = (t, a, frontmatter(domain / rel))
    breaks = []

    def resolve(rel, link):
        target = Path(os.path.normpath((rel.parent / link).as_posix()))
        return target if target in objs else None

    parts_of = {}
    for rel, (t, a, fm) in objs.items():
        row = types[t]
        say = lambda kind, what: breaks.append(f"{rel.as_posix()}: {t}: {kind}: {what}")
        for name, (kind, req) in all_fields(types, t).items():
            if name not in fm:
                if req:
                    say("field", f"{name} missing")
            elif kind.startswith("link:"):
                target = None if isinstance(fm[name], list) else resolve(rel, fm[name])
                if target is None or not is_a(types, objs[target][0], kind[5:]):
                    say("link", f"{name} {fm[name]} is not a {kind[5:]}")
            elif not kind_ok(kind, fm[name]):
                say("field", f"{name} is not a {kind}")
        if a not in row["areas"]:
            say("area", f"{a}, not {' or '.join(sorted(row['areas']))}")
        parts_of[rel] = []
        for key, allowed, values in (("parts", row["made_of"], True), ("links", row["links_to"], False)):
            entries = fm.get(key, [])
            for entry in entries if isinstance(entries, list) else [entries]:
                link, *pairs = entry.split()
                target = resolve(rel, link)
                if target is None:
                    say("link", f"{link} not found")
                    continue
                tt = objs[target][0]
                if not any(is_a(types, tt, x) for x in allowed):
                    say("link", f"{link} is a {tt}, not {' or '.join(sorted(allowed)) or 'allowed'}")
                if not values:
                    continue
                parts_of[rel].append(target)
                vals = dict(p.partition("=")[::2] for p in pairs)
                for name, (kind, req) in row["part_fields"].items():
                    if name not in vals:
                        if req:
                            say("link", f"{link} lacks {name}")
                    elif not kind_ok(kind, vals[name]):
                        say("link", f"{link} {name} is not a {kind}")
    for rel in objs:
        seen, todo = set(), list(parts_of[rel])
        while todo:
            x = todo.pop()
            if x == rel:
                breaks.append(f"{rel.as_posix()}: {objs[rel][0]}: cycle: part of itself")
                break
            if x not in seen:
                seen.add(x)
                todo += parts_of.get(x, [])
    for rel in untyped:
        print(f"untyped {rel.as_posix()}")
    for b in breaks:
        print(b)
    if breaks:
        return 1
    print(f"ok {domain}")
    return 0


def draw(types):
    """One graph block: each type a node with its fields, and is a, made of and links to links."""
    node = lambda name: name.replace(" ", "_")
    out = ["```graph"]
    for name, t in types.items():
        fs = ", ".join(f"{k}: {kind}{'!' if req else ''}" for k, (kind, req) in t["fields"].items())
        out.append(f"{node(name)}: {t['coll']}" + (f". {fs}" if fs else ""))
    for name, t in types.items():
        links = ([f"{node(t['parent'])} [is a]"] if t["parent"] else []) + \
            [f"{node(x)} [made of]" for x in sorted(t["made_of"])] + [f"{node(x)} [links to]" for x in sorted(t["links_to"])]
        if links:
            out.append(f"{node(name)} -> " + ", ".join(links))
    out.append("```")
    return "\n".join(out)


PAGE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>KB map</title>
<style>
:root { --bg: #191970; --card: #001F3F; --text: #FAF0E6; --line: #4A6A88; --focus: #A8D8EA; --tan: #D2B48C; }
body { margin: 0; padding: 16px; background: var(--bg); color: var(--text); font-family: -apple-system, sans-serif; }
header { display: flex; justify-content: space-between; align-items: center; gap: 8px; margin-bottom: 12px; }
header h1 { font-size: 18px; margin: 0; } #where { color: var(--tan); font-size: 13px; }
.tools button { background: var(--card); color: var(--text); border: 1px solid var(--line); border-radius: 6px; padding: 6px 10px; cursor: pointer; }
ul { list-style: none; margin: 0; padding-left: 20px; border-left: 1px solid var(--line); }
#map > ul { padding-left: 0; border-left: none; }
li { margin: 4px 0; }
li > button { background: var(--card); color: var(--text); border: 1px solid var(--line); border-radius: 6px; padding: 4px 8px; cursor: pointer; text-align: left; }
li > button.leaf { border-style: dashed; color: var(--tan); font-family: ui-monospace, monospace; font-size: 12px; }
li > button.focus { border-color: var(--focus); box-shadow: 0 0 0 1px var(--focus); }
li > button.source { background: #6B7158; color: var(--text); } li > button.staging { background: #4A6A88; color: var(--text); }
/* Horizontal: each node's children sit in a column to its right. */
#map.wide { overflow-x: auto; }
#map.wide li { display: flex; align-items: flex-start; gap: 12px; }
#map.wide li > button { white-space: nowrap; }
</style></head><body>
<header><div><h1>KB map</h1><div id="where"></div></div>
<div class="tools"><button id="flip">Horizontal</button> <button id="reset">Reset</button></div></header>
<div id="map"></div>
<script type="application/json" id="tree">__TREE__</script>
<script>__SCRIPT__</script>
</body></html>
"""


def source_types(domain):
    """`## Source types` of the domain CLAUDE.md: [(type, glob)]. A source is never edited, so its type lives here."""
    lines = (Path(domain) / "CLAUDE.md").read_text().splitlines() if (Path(domain) / "CLAUDE.md").exists() else []
    out, on = [], False
    for x in lines:
        if x.startswith("## "):
            on = x.strip() == "## Source types"
        elif on and x.startswith("|") and not x.startswith("|---"):
            c = [y.strip().strip("`") for y in x.strip().strip("|").split("|")]
            if len(c) >= 2 and c[0] != "Type":
                out.append((c[0], c[1]))
    return out


def file_type(domain, rel, globs):
    """The type of a source or staging file: its frontmatter, else the first glob of `## Source types` it fits."""
    import fnmatch
    if rel.suffix == ".md":
        t = frontmatter(Path(domain) / rel).get("type")
        if t:
            return t
    return next((t for t, g in globs if fnmatch.fnmatch(rel.as_posix(), g) or fnmatch.fnmatch(rel.name, g)), None)


AREA_FILL = {"source": "#6B7158", "staging": "#4A6A88"}  # olive and slate blue, in the kitchen sink for review


def flow(domain):
    """The flow of a domain as a graph block: each source file, each staging page, then the types.
    A link into a type counts its pages that cite the file. Fields show only on hover."""
    domain = Path(domain)
    files = [f.relative_to(domain) for f in domain.rglob("*") if not f.is_dir()
             and not any(x.startswith(".") for x in f.relative_to(domain).parts)]

    globs = source_types(domain)
    # Only consolidated pages make a type on the right. A staging type stays with staging.
    pt = {t: r for t, r in page_types(domain).items()
          if any(frontmatter(domain / f).get("type") == t for f in files
                 if f.suffix == ".md" and ".staging." not in f.name and ".source." not in f.name)}
    inputs = {}  # rel -> [node, area]
    for rel in sorted(files):
        area = "source" if ".source." in rel.name else "staging" if ".staging." in rel.name else None
        if area:
            inputs[rel] = [file_type(domain, rel, globs) or f"untyped_{area}", area]
    # One name for two areas, or a staging type that is also a consolidated type: the area goes after it.
    areas_of = {}
    for node, area in inputs.values():
        areas_of.setdefault(node, set()).add(area)
    for v in inputs.values():
        if len(areas_of[v[0]]) > 1 or v[0] in pt:
            v[0] = f"{v[0]}_{v[1]}"
    loose = 0
    links = {}  # (from, to) -> set of citing pages, or a relationship name

    for rel in files:
        if rel.suffix != ".md" or rel.name in ("CLAUDE.md", "kb-flow.md") or ".source." in rel.name:
            continue
        fm = frontmatter(domain / rel)
        if ".staging." in rel.name:
            to = inputs[rel][0]
        elif fm.get("type"):
            to = fm["type"]
        else:
            to, loose = "miscellaneous", loose + 1
        text = (domain / rel).read_text(errors="ignore")
        for src, (node, _) in inputs.items():
            if node != to and src.name in text:
                links.setdefault((node, to), set()).add(rel)
    for t, r in pt.items():
        for kind, x in r["rels"]:
            if kind == "made of":
                links[(x, t)] = "made of"
            elif kind == "part of":
                links[(t, x)] = "part of"

    out = ["```graph", "direction right"]  # left to right, as a pipeline reads
    for area, title in (("source", "Source"), ("staging", "Staging")):
        ids = sorted({v[0] for v in inputs.values() if v[1] == area})
        if ids:
            out.append(f"[{title}] " + " ".join(ids))
            out.append(f"fill {AREA_FILL[area]} " + " ".join(ids))
    # The types stand with no box: a box name there crosses the links into miscellaneous.
    types = sorted(pt) + (["miscellaneous"] if loose else [])
    for node in sorted({v[0] for v in inputs.values()}):
        rels = sorted(r.as_posix() for r, v in inputs.items() if v[0] == node)
        area, more = inputs[next(r for r, v in inputs.items() if v[0] == node)][1], len(rels) - 8
        out.append(f"{node}: {area}, {len(rels)} file{'s' if len(rels) != 1 else ''}: "
                   + ", ".join(rels[:8]) + (f", and {more} more" if more > 0 else "") + ".")
    for t in sorted(pt):
        r, n = pt[t], sum(1 for rel in files if rel.suffix == ".md" and frontmatter(domain / rel).get("type") == t)
        fields = ", ".join(sorted(r["fields"])) or "none"
        out.append(f"{t}: {n} page{'s' if n != 1 else ''}. Fields: {fields}." + (f" Is a {r['parent']}." if r["parent"] else ""))
    if loose:
        out.append(f"miscellaneous: {loose} pages with no type.")
    order = [n for a in ("source", "staging") for n in sorted({v[0] for v in inputs.values() if v[1] == a})] + types
    for a in order:
        outs = [(b, v) for (x, b), v in links.items() if x == a]
        if outs:
            outs.sort(key=lambda bv: order.index(bv[0]) if bv[0] in order else len(order))
            # A link into a type or miscellaneous counts its pages. A link into one page needs no count.
            out.append(f"{a} -> " + ", ".join(
                b + (f" [{v}]" if isinstance(v, str) else f" [{len(v)}]") for b, v in outs))
    out.append("```")
    return "\n".join(out)


def pages_of(dom):
    """Each .md page of a domain, relative, with no CLAUDE.md, map page or dot folder."""
    return sorted(p.relative_to(dom) for p in dom.rglob("*.md")
                  if p.name not in ("CLAUDE.md", "kb-flow.md") and not any(x.startswith(".") for x in p.relative_to(dom).parts))


def kb_tree(roots):
    """Every KB of the roots list as one tree: 0 all KBs, 1 KB, 2 domain, 3 area, 4 type or page, 5 field."""
    nodes = {"all": {"name": "all KBs", "parent": None, "level": 0}}
    for kb in roots:
        nodes[kb.name] = {"name": kb.name, "parent": "all", "level": 1}
        for dom in sorted(d for d in kb.iterdir()
                          if d.is_dir() and not d.name.startswith(".") and (d / "CLAUDE.md").exists()):
            did = f"{kb.name}/{dom.name}"
            nodes[did] = {"name": dom.name, "parent": kb.name, "level": 2}
            try:
                types = read_table(dom / "CLAUDE.md")
            except BadTable as e:
                print(f"{dom / 'CLAUDE.md'}: {e}: drawn from its pages or folders")
                types = None
            # The three areas of the kb skill. Source and staging fold, with their counts.
            files = [f.relative_to(dom) for f in dom.rglob("*") if not f.is_dir()
                     and f.name not in ("CLAUDE.md", "kb-map.html", "kb-flow.md") and not any(x.startswith(".") for x in f.relative_to(dom).parts)]
            src = sorted(f for f in files if ".source." in f.name)
            stg = sorted(f for f in files if ".staging." in f.name)
            con = [f for f in pages_of(dom) if ".source." not in f.name and ".staging." not in f.name]
            cites = ", cites source 1 to many"
            cid0 = f"{did}/consolidated"
            nodes[cid0] = {"name": f"consolidated ({len(con)})" + cites, "parent": did, "level": 3}
            for area, items, name in (("staging", stg, f"staging ({len(stg)})" + cites), ("source", src, f"source ({len(src)})")):
                aid = f"{did}/{area}"
                nodes[aid] = {"name": name, "parent": did, "level": 3, "folded": True, "area": area}
                globs = source_types(dom)
                by = {}
                for rel in items:
                    by.setdefault(file_type(dom, rel, globs) or "untyped", []).append(rel)
                for t, rels in sorted(by.items()):
                    tid = f"{aid}/{t}"
                    nodes[tid] = {"name": f"{t} ({len(rels)})", "parent": aid, "level": 4, "folded": True, "area": area}
                    for rel in rels:
                        nodes[f"{tid}#{rel.as_posix()}"] = {"name": rel.as_posix(), "parent": tid, "level": 5, "area": area}
            pt = page_types(dom)
            if pt:
                for t, r in sorted(pt.items()):
                    cid = f"{did}/{t}"
                    nodes[cid] = {"name": t + (f" (is a {r['parent']})" if r["parent"] else ""), "parent": cid0, "level": 4}
                    for f in sorted(r["fields"]):
                        nodes[f"{cid}#{f}"] = {"name": f, "parent": cid, "level": 5}
                    for k, x in sorted(r["rels"]):
                        nodes[f"{cid}#{k}:{x}"] = {"name": f"{k} {x}", "parent": cid, "level": 5}
            elif types:
                for t, row in types.items():
                    cid = f"{did}/{t}"
                    nodes[cid] = {"name": t + (f" (is a {row['parent']})" if row["parent"] else ""), "parent": cid0, "level": 4}
                    for f, (kind, req) in all_fields(types, t).items():
                        nodes[f"{cid}#{f}"] = {"name": f"{f}: {kind}" + ("!" if req else ""), "parent": cid, "level": 5}
            # Each consolidated page that fits no type sits by itself under miscellaneous, a list to shrink.
            loose = [rel for rel in con if not frontmatter(dom / rel).get("type")
                     and not (types and not pt and type_of(types, rel)[0])]
            if loose:
                mid = f"{did}/miscellaneous"
                nodes[mid] = {"name": f"miscellaneous ({len(loose)})", "parent": cid0, "level": 4, "folded": True}
                for rel in loose:
                    nodes[f"{mid}#{rel.as_posix()}"] = {"name": rel.as_posix(), "parent": mid, "level": 5}
    return nodes


def write_maps(roots_file):
    roots = [Path(os.path.expanduser(x.strip())) for x in roots_file.read_text().splitlines()
             if x.strip() and not x.strip().startswith("#")]
    nodes = kb_tree([r for r in roots if r.is_dir()])
    script = (Path(__file__).resolve().parent.parent / "assets" / "kb-map.js").read_text()
    for kb in roots:
        if not kb.is_dir():
            print(f"skip {kb}: not a folder")
            continue
        # One page next to each CLAUDE.md: the KB root and each domain, each opened on its own node.
        homes = [(kb, kb.name)] + [(kb / i.split("/", 1)[1], i) for i, n in nodes.items()
                                   if n["level"] == 2 and n["parent"] == kb.name]
        for folder, home in homes:
            tree = json.dumps({"nodes": nodes, "home": home}, ensure_ascii=False, indent=1).replace("</", "<\\/")
            page = folder / "kb-map.html"
            page.write_text(PAGE.replace("__TREE__", tree).replace("__SCRIPT__", script))
            print(f"map {page}")
            if folder != kb:  # each domain also gets its flow, for VS Code's preview
                (folder / "kb-flow.md").write_text(
                    f"# Flow of {folder.name}\n\nWritten by `/kb map`. Source on the left, staging next, the types on the right. "
                    "A number on a link counts the pages that cite the node it comes from. Hover a node for its fields.\n\n"
                    + flow(folder) + "\n")
    return 0


def selftest():
    """One domain per case. Each case names the break it catches."""
    import io
    from contextlib import redirect_stdout

    HEAD = "| Type | Is a | Collection | Areas | Made of | Part fields | Links to | Fields |\n|---|---|---|---|---|---|---|---|\n"
    ROWS = (
        "| item | | `pantry/items/<name>.md` | consolidated | | | | `fresh_days: number!`, `for: text` |\n"
        "| version | | `meals/staging/<name>/<name>.md` | staging | item | `grams: number!` | | `fullness: score!`, `notes: text`, `good_for: list` |\n"
        "| meal | version | `meals/<name>.md` | consolidated | item, meal | `grams: number!` | version | `like: text` |\n"
    )

    def dom(pages, rows=ROWS, table=True):
        root = Path(tempfile.mkdtemp()) / "food"
        root.mkdir()
        (root / "CLAUDE.md").write_text("# Food\n\n" + ("## Types\n\n" + HEAD + rows if table else "No table.\n"))
        for rel, text in pages.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text)
        return root

    def run(*argv):
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = main(list(argv))
        return code, buf.getvalue()

    def fm(**kv):
        lines = []
        for k, v in kv.items():
            if isinstance(v, list):
                lines.append(f"{k}:")
                lines += [f"- {x}" for x in v]
            else:
                lines.append(f"{k}: {v}")
        return "---\n" + "\n".join(lines) + "\n---\n# page\n"

    ITEM = fm(fresh_days=5)
    fails = []

    def case(name, cond, why):
        print(("ok   " if cond else "FAIL ") + name + ("" if cond else f": {why}"))
        if not cond:
            fails.append(name)

    # Data object first: missingScoreTest, wrongKindTest, areaTest, fitsTest, inheritTest.
    d = dom({"meals/staging/鸡/v1.staging.md": fm(notes="x")})
    code, out = run("check", str(d))
    case("missingScoreTest", code == 1 and "meals/staging/鸡/v1.staging.md: version: field: fullness missing" in out,
         f"a version with no fullness must break: {out!r}")
    d = dom({"meals/staging/鸡/v1.staging.md": fm(fullness="high")})
    code, out = run("check", str(d))
    case("wrongKindTest", code == 1 and "version: field: fullness is not a score" in out, f"a text score must break: {out!r}")
    d = dom({"meals/staging/鸡/v1.staging.md": fm(fullness=9)})
    code, out = run("check", str(d))
    case("scoreRangeTest", code == 1 and "fullness is not a score" in out, f"a score of 9 must break: {out!r}")
    d = dom({"pantry/items/南瓜.staging.md": ITEM})
    code, out = run("check", str(d))
    case("areaTest", code == 1 and "pantry/items/南瓜.staging.md: item: area: staging" in out, f"an item in staging must break: {out!r}")
    d = dom({"pantry/items/南瓜.md": ITEM})
    code, out = run("check", str(d))
    case("fitsTest", code == 0 and out.strip().endswith("ok " + str(d)), f"an item with its field must fit: {out!r}")
    d = dom({"meals/鸡.md": fm(like="yes")})
    code, out = run("check", str(d))
    case("inheritTest", code == 1 and "meals/鸡.md: meal: field: fullness missing" in out,
         f"a meal must get the required fullness of version: {out!r}")
    d = dom({"pantry/items/南瓜.md": fm(fresh_days="soon")})
    code, out = run("check", str(d))
    case("fitHasEachRequired", code == 1 and "fresh_days is not a number" in out, f"a value of the wrong kind must not fit: {out!r}")
    d = dom({"meals/staging/鸡/v1.staging.md": fm(fullness=4, good_for="fibre")})
    code, out = run("check", str(d))
    case("listKindTest", code == 1 and "good_for is not a list" in out, f"a scalar in a list field must break: {out!r}")

    # Grouping: partValTest, cycleTest, noCycleTest, lostPartFound, links.
    d = dom({"pantry/items/南瓜.md": ITEM, "meals/鸡.md": fm(fullness=4, parts=["../pantry/items/南瓜.md"])})
    code, out = run("check", str(d))
    case("partValTest", code == 1 and "meals/鸡.md: meal: link: ../pantry/items/南瓜.md lacks grams" in out, f"a part with no grams must break: {out!r}")
    d = dom({"pantry/items/南瓜.md": ITEM, "meals/鸡.md": fm(fullness=4, parts=["../pantry/items/南瓜.md grams=many"])})
    code, out = run("check", str(d))
    case("partKindTest", code == 1 and "grams is not a number" in out, f"a part value of the wrong kind must break: {out!r}")
    d = dom({"meals/鸡.md": fm(fullness=4, parts=["pantry/items/none.md grams=4"])})
    code, out = run("check", str(d))
    case("lostPartFound", code == 1 and "meals/鸡.md: meal: link: pantry/items/none.md not found" in out, f"a lost part must break: {out!r}")
    d = dom({"meals/staging/x/v1.staging.md": fm(fullness=4), "meals/鸡.md": fm(fullness=4, parts=["staging/x/v1.staging.md grams=4"])})
    code, out = run("check", str(d))
    case("partTypeTest", code == 1 and "is a version, not item or meal" in out, f"a part of a type not in Made of must break: {out!r}")
    d = dom({"meals/staging/x/v1.staging.md": fm(fullness=4), "meals/鸡.md": fm(fullness=4, links=["staging/x/v1.staging.md"])})
    code, out = run("check", str(d))
    case("linkTest", code == 0, f"a link to a version, relative to the page, must pass: {out!r}")
    d = dom({"meals/鸡.md": fm(fullness=4, links=["staging/x/none.staging.md"])})
    code, out = run("check", str(d))
    case("lostLinkTest", code == 1 and "link: staging/x/none.staging.md not found" in out, f"a lost link must break: {out!r}")
    d = dom({"meals/a.md": fm(fullness=4, parts=["b.md grams=1"]), "meals/b.md": fm(fullness=4, parts=["a.md grams=1"])})
    code, out = run("check", str(d))
    case("cycleTest", code == 1 and "meals/a.md: meal: cycle:" in out and "meals/b.md: meal: cycle:" in out, f"two meals made of each other must break: {out!r}")
    d = dom({"meals/a.md": fm(fullness=4, parts=["a.md grams=1"])})
    code, out = run("check", str(d))
    case("selfPartIsCycle", code == 1 and "meals/a.md: meal: cycle:" in out, f"a meal made of itself must break: {out!r}")
    d = dom({"pantry/items/南瓜.md": ITEM, "meals/a.md": fm(fullness=4, parts=["../pantry/items/南瓜.md grams=400"])})
    code, out = run("check", str(d))
    case("noCycleTest", code == 0, f"a meal made of an item must pass: {out!r}")

    # The states: cleanTest, brokenTest, skippedTest, badTableTest, drawnTest, and their invariants.
    d = dom({"pantry/foods/南瓜.md": "# 南瓜\n", "pantry/items/南瓜.md": ITEM, "photo.jpeg": "x"})
    code, out = run("check", str(d))
    case("cleanTest", code == 0 and "untyped pantry/foods/南瓜.md" in out and "untyped photo.jpeg" in out,
         f"untyped pages are listed and the domain is clean: {out!r}")
    case("untypedNotABreak", ": cycle:" not in out and ": field:" not in out, f"an untyped page must not break: {out!r}")
    d = dom({"pantry/items/a.md": "# a\n", "pantry/items/b.md": fm(fresh_days=2), "pantry/items/c.md": "# c\n"})
    code, out = run("check", str(d))
    lines = [x for x in out.splitlines() if ": item: " in x]
    case("brokenTest", code == 1 and len(lines) == 2 and all("fresh_days missing" in x for x in lines),
         f"one line for each page that breaks: {out!r}")
    case("brokenNamesEach", "pantry/items/b.md" not in out, f"a page that fits gets no line: {out!r}")
    d = dom({"pantry/items/南瓜.md": "# x\n"}, table=False)
    code, out = run("check", str(d))
    case("skippedTest", code == 0 and out.strip() == f"skip {d}: no Types table", f"no table must skip: {out!r}")
    code, out = run("draw", str(d))
    case("drawnOnlyFromTable", code == 0 and "```graph" not in out, f"no table must draw nothing: {out!r}")
    d = dom({"pantry/items/南瓜.md": "# x\n"}, rows="| item | | `pantry/items/<name>.md` | consolidated | | | | `fresh_days: colour!` |\n")
    code, out = run("check", str(d))
    case("badTableTest", code == 2 and "Types row 1: unknown kind colour" in out and "南瓜" not in out, f"an unknown kind must stop: {out!r}")
    d = dom({}, rows="| meal | dish | `meals/<name>.md` | consolidated | | | | |\n")
    code, out = run("check", str(d))
    case("badTableStops", code == 2 and "unknown type dish" in out, f"an unknown parent type must stop: {out!r}")
    d = dom({}, rows="| a | b | `a/<name>.md` | consolidated | | | | |\n| b | a | `b/<name>.md` | consolidated | | | | |\n")
    code, out = run("check", str(d))
    case("isACycleTest", code == 2 and "is a cycle" in out, f"a type that is its own parent must stop: {out!r}")
    d = dom({}, rows="| item | | `pantry/items/<name>.md` | consolidated |\n")
    code, out = run("check", str(d))
    case("rowWidthTest", code == 2 and "Types row 1" in out, f"a short row must stop: {out!r}")
    d = dom({})
    code, out = run("draw", str(d))
    case("drawnTest", code == 0 and out.startswith("```graph") and "meal -> version [is a]" in out
         and "version -> item [made of]" in out and "version [links to]" in out and "fullness: score!" in out,
         f"draw must give an OOP graph block: {out!r}")

    # The map: mappedTest, mappedOnlyWhenAsked.
    kb1 = dom({"pantry/items/南瓜.md": ITEM, "pantry/foods/x.md": "# x\n"}).parent
    kb2 = Path(tempfile.mkdtemp()) / "eventPNL"
    (kb2 / "knowledge-base" / "notes").mkdir(parents=True)
    (kb2 / "knowledge-base" / "notes" / "a.md").write_text("# a\n")
    (kb2 / "knowledge-base" / "CLAUDE.md").write_text("# KB\n")
    roots = Path(tempfile.mkdtemp()) / "kb-roots.txt"
    roots.write_text(f"# one KB folder per line\n{kb1}\n{kb2}\n")
    code, out = run("map", str(roots))
    page1, page2 = kb1 / "kb-map.html", kb2 / "kb-map.html"
    ok = code == 0 and page1.exists() and page2.exists()
    t1 = page1.read_text() if page1.exists() else ""
    t2 = page2.read_text() if page2.exists() else ""
    case("mappedTest", ok and f"map {page1}" in out and '"home": "' + kb1.name + '"' in t1 and '"home": "eventPNL"' in t2
         and '"eventPNL/knowledge-base/miscellaneous#notes/a.md"' in t1 and '"eventPNL/knowledge-base/notes"' not in t1 and '"' + kb1.name + '/food/item#fresh_days"' in t1,
         f"each KB gets a page with every KB in its tree and itself as home: {out!r}")
    case("mappedOnlyWhenAsked", ok and ": field:" not in out and "untyped" not in out, f"a map checks no page: {out!r}")
    dpage = kb1 / "food" / "kb-map.html"
    case("domainPageTest", dpage.exists() and f'"home": "{kb1.name}/food"' in dpage.read_text() and f"map {dpage}" in out,
         "each domain gets its own page next to its CLAUDE.md, opened on that domain")
    case("mapScriptTest", "function hidden(" in t1 and 'id="all"' not in t1 and "Reset" in t1 and 'id="flip"' in t1, "the page carries kb-map.js, Reset and the flip of the layout, and no Show all")

    # Types from the frontmatter of the pages, with no table.
    fd = dom({"foods/rice.md": "---\ntype: food\nfresh_days: 3\n---\n# rice\n",
              "foods/egg.md": "---\ntype: food\nstorage: fridge\n---\n# egg\n",
              "dishes/congee.md": "---\ntype: dish\nis_a: meal\neasy: 5\nmade_of:\n- [rice](../foods/rice.md)\n---\n# congee\n",
              "notes.md": "# no frontmatter\n"}, table=False)
    pt = page_types(fd)
    case("unionTest", pt.get("food", {}).get("fields") == {"fresh_days", "storage"} and set(pt) == {"food", "dish"},
         f"two pages of one type give the union of their keys, an untyped page gives no type: {pt!r}")
    case("madeOfTest", ("made of", "food") in pt.get("dish", {}).get("rels", set()), f"a made_of link draws made of: {pt!r}")
    case("isATest", pt.get("dish", {}).get("parent") == "meal", f"is_a draws is a: {pt!r}")
    fh = dom({"foods/tofu.md": "---\ntype: food\n---\n# tofu\n\n| Figure | Per 100 g |\n|---|---|\n\n- Shelf life: 5 days\n- Kept: fridge\n\n## Notes\n\n- Not: a field\n"},
             table=False)
    case("keyLineTest", page_types(fh).get("food", {}).get("fields") == {"shelf_life", "kept"},
         f"the `- Key: value` lines before the first ## heading are fields too: {page_types(fh)!r}")
    code, out = run("draw", str(fd))
    case("noDrift", code == 0 and "dish -> meal [is a], food [made of]" in out and "food: fresh_days, storage" in out,
         f"draw reads the pages, no table: {out!r}")
    fe = dom({"plans/week.md": '---\ntype: "plan"\n---\n# week\n',
              "dishes/soup.md": "---\ntype: dish\npart_of:\n  - [week](../plans/week.md#mon)\nlinks_to: ../plans/week.md\n---\n",
              ".hidden/x.md": "---\ntype: ghost\n---\n"})
    pe = page_types(fe)
    case("partOfLinksToTest", pe.get("dish", {}).get("rels") == {("part of", "plan"), ("links to", "plan")} and "ghost" not in pe,
         f"an indented item with an anchor, a plain path, a quoted type, and no dot folder: {pe!r}")
    code, out = run("draw", str(fe))
    case("pagesBeatTableTest", code == 0 and "dish -> plan [links to], plan [part of]" in out,
         f"a domain whose pages carry type: draws from them, not its table: {out!r}")
    roots2 = Path(tempfile.mkdtemp()) / "kb-roots.txt"
    roots2.write_text(f"{fd.parent}\n")
    run("map", str(roots2))
    t3 = (fd.parent / "kb-map.html").read_text()
    case("untypedMakesNoType", f'"{fd.parent.name}/food/dish#easy"' in t3 and f'"{fd.parent.name}/food/foods"' not in t3
         and f'"{fd.parent.name}/food/miscellaneous#notes.md"' in t3,
         "the map shows types from the pages, and the untyped page under miscellaneous, not folders")
    (fd / "misc").mkdir()
    (fd / "misc" / "loose.md").write_text("# no type\n")
    run("map", str(roots2))
    t4 = (fd.parent / "kb-map.html").read_text()
    case("miscTest", f'"{fd.parent.name}/food/miscellaneous#misc/loose.md"' in t4 and f'"{fd.parent.name}/food/misc"' not in t4
         and '"miscellaneous (2)"' in t4 and '"folded": true' in t4,
         "each untyped page shows by itself under miscellaneous, with the count, so the list can shrink")
    # The three areas: source and staging fold with their counts, and each says what it cites.
    (fd / "2026-11-20-visit.source.md").write_text("x")
    (fd / "2026-11-20-scan.source.jpeg").write_text("x")
    (fd / "trend.staging.md").write_text("X [1] [2].\n\n## Sources\n\n1. [a](2026-11-20-visit.source.md)\n2. [b](2026-11-20-scan.source.jpeg)\n")
    nt, k = kb_tree([fd.parent]), f"{fd.parent.name}/food"
    case("areaTest", nt[f"{k}/source"]["name"] == "source (2)" and nt[f"{k}/source"].get("folded")
         and nt[f"{k}/staging"]["name"] == "staging (1), cites source 1 to many" and nt[f"{k}/staging"].get("folded")
         and nt[f"{k}/consolidated"]["name"].startswith("consolidated (5)")
         and nt[f"{k}/dish"]["parent"] == f"{k}/consolidated" and nt[f"{k}/miscellaneous"]["parent"] == f"{k}/consolidated"
         and f"{k}/source/untyped#2026-11-20-scan.source.jpeg" in nt and f"{k}/staging/untyped#trend.staging.md" in nt
         and f"{k}/miscellaneous#trend.staging.md" not in nt and nt[f"{k}/staging/untyped#trend.staging.md"].get("area") == "staging" and nt[f"{k}/source"].get("area") == "source",
         f"each domain shows source, staging and consolidated: {[(i, n['name']) for i, n in nt.items() if i.startswith(k)]!r}")

    # The flow: source groups, then staging, then the types, each link with how many pages use it.
    (fd / "notes").mkdir()
    (fd / "notes" / "2026-11-21-call.source.md").write_text("x")
    (fd / "dishes" / "congee.md").write_text((fd / "dishes" / "congee.md").read_text()
                                             + "\n- Source: trend.staging.md and notes/2026-11-21-call.source.md\n")
    # A source file takes its type from `## Source types`, since a source is never edited.
    with open(fd / "CLAUDE.md", "a") as f:
        f.write("\n## Source types\n\n| Type | Files |\n|---|---|\n| visit_note | `*-visit.source.md` |\n| photo | `*.source.jpeg` |\n")
    (fd / "trend.staging.md").write_text("---\ntype: trend_draft\n---\n" + (fd / "trend.staging.md").read_text())
    g = flow(fd)
    case("flowTest", g.startswith("```graph\ndirection right\n") and "[Source] photo untyped_source visit_note\n" in g
         and "[Staging] trend_draft\n" in g and "fill #6B7158 photo untyped_source visit_note\n" in g
         and "\nphoto -> trend_draft [1]\n" in g and "\nvisit_note -> trend_draft [1]\n" in g
         and "\nuntyped_source -> dish [1]\n" in g and "\ntrend_draft -> dish [1]\n" in g and "food -> dish [made of]" in g
         and "visit_note: source, 1 file: 2026-11-20-visit.source.md." in g and "2026-11-20-visit" not in g.split("\n")[2],
         f"each node is an object type with its count, the paths only in the hover text: {g!r}")
    nt = kb_tree([fd.parent])
    case("mapTypesTest", nt[f"{k}/source/photo"]["name"] == "photo (1)" and nt[f"{k}/source/photo"].get("folded")
         and f"{k}/source/photo#2026-11-20-scan.source.jpeg" in nt and nt[f"{k}/staging/trend_draft"]["name"] == "trend_draft (1)",
         f"the map groups source and staging by type: {[i for i in nt if i.startswith(k + '/s')]!r}")
    run("map", str(roots2))
    fp = fd / "kb-flow.md"
    case("flowPageTest", fp.exists() and fp.read_text().startswith("# Flow of food\n") and g in fp.read_text()
         and "kb-flow.md" not in json.dumps(kb_tree([fd.parent]), ensure_ascii=False),
         "map writes the flow next to each domain CLAUDE.md, and the flow page is no page of the domain")

    # Matching: the first row wins, and the area suffix is stripped before the match.
    rows = "| plan | | `meals/<date>.md` | consolidated | | | | `from: date!` |\n" + ROWS
    d = dom({"meals/2026-11-20.md": fm(**{"from": "2026-11-20"})}, rows=rows)
    code, out = run("check", str(d))
    case("firstRowWinsTest", code == 0, f"a dated page must take the first row, plan: {out!r}")
    d = dom({"meals/staging/鸡/v1.staging.md": fm(fullness=3)})
    code, out = run("check", str(d))
    case("suffixStrippedTest", code == 0 and "untyped" not in out, f"a .staging. name must match its row: {out!r}")

    print(f"{len(fails)} failed" if fails else "all passed")
    return 1 if fails else 0


def main(argv):
    if argv == ["--test"]:
        return selftest()
    if argv[:1] == ["flow"] and len(argv) == 2:
        print(flow(argv[1]))
        return 0
    if argv[:1] == ["map"] and len(argv) <= 2:
        default = Path(__file__).resolve().parent.parent / "assets" / "kb-roots.txt"
        return write_maps(Path(argv[1]) if len(argv) == 2 else default)
    if len(argv) != 2 or argv[0] not in ("check", "draw"):
        print(__doc__, file=sys.stderr)
        return 2
    return run_domain(argv[0], Path(argv[1]))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
