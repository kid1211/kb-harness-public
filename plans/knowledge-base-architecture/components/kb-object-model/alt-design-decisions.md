# KB object model: designs not chosen

- **A schema page for each domain, such as `types.yaml`.** Not chosen: the script uses the standard library only. Claude reads the domain's `CLAUDE.md` before it writes there, so the table goes in it.
- **One folder for each type, with no name pattern.** Not chosen: the food proposal has dated names, such as `meals/plan/<date>.md`, so a type needs a pattern too.
- **A hook on each write that checks the type.** Not chosen for the first build: the check on demand comes first. A hook can call the same function later.
- **A picture made only by hand.** Not chosen: a hand graph drifts from the table. The levels graph stays by hand, since it does not change. Each domain graph comes from its table.
- **The type check inside `kb-check.py`.** Replaced on 2026-11-20: the parent level builds `kb-check.py`, and a path has one level. The check is `kb-types.py`.
- **A page in no collection is a break.** Replaced on 2026-11-20: the user accepts pages with no frontmatter. They are listed as untyped.
- **Part values as nested frontmatter.** Not chosen: the script parses flat lines only. A part line carries `key=value` pairs.
- **The most specific pattern wins.** Not chosen: the first row that wins is one rule the user can see in the table order.
