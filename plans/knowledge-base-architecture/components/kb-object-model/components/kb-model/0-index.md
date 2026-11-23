# KB model

## Goal

Each KB has its whole object model in one Quint model, apart from the pages. Each typed file of the KB maps to one object of the model. A drift check runs the model against the files and names each file that breaks it. The check of the public mark waits. This is for KB files only. Draft.

Builds: the rules of every KB model `.claude/lib/kb-model/kb-model-rules.qnt` and the script that writes the files as Quint data and runs the drift check `.claude/lib/kb-model/kb-model.py`.
Uses: the readers of `.claude/skills/kb/scripts/kb-types.py`, the proof of concept in `personal/claude-research/staging/2026-11-20-kb-object-quint/`, and the pinned Quint of the harness.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- ✅ **R13. One model for each KB:** [implement] Each KB has one Quint model, `kb-model.qnt`, next to its root `CLAUDE.md`. It holds every type of every domain of that KB. Each type has its areas, its `is_a` parent, its fields, the types it is made of, part of or links to, the kind of each part value, such as grams, and the types its pages may cite. A citation is a link in the body of a page. *(the user, 2026-11-20)*
- ✅ **R19. Types as data, rules as functions:** [implement] The model holds each type as a value, so a type can carry its parent, its fields and its links. Each field has a name, a kind, a required mark and a public mark. The kinds are those of R39 of the parent. A type gets each field of each type over it by `is_a`. The rules are pure functions in one shared rules file of the harness library `.claude/lib/kb-model/`, which each KB model imports. A skill folder holds no Quint file. A link between objects is a path, and a rule checks the type of the file at that path.
- ⚠️ **R4. Public fields in the frontmatter:** [implement] Deferred by the user: no check of the public mark for now. When the check comes, a field marked public sits in the frontmatter or a key line of each page of its type, and a field the model does not mark public is drift. A field with no public mark is a value a script works out, and no page writes it. *(the user, 2026-11-20)*
- ✅ **R5. Each file maps to one object:** [implement] A page maps to an object by its `type:`. A source file is never edited, so the model maps it by a file pattern. A file that maps to no type is untyped: the check lists it, and it is not a break.
- ✅ **R21. The drift check:** [implement] A script in `.claude/lib/kb-model/` reads the files of a KB, writes them as Quint data, and runs the model on them. It prints one line per break, with the path, the rule and what the rule is about, and exits 1. With no break, it lists the untyped files and exits 0. If the model does not typecheck, the script exits 2.
  - Design input: The fields of a page are its frontmatter keys and its `- Key: value` lines before the first `##`. The keys `type:`, `is_a:`, `part_of:`, `made_of:` and `links_to:` are no fields. The breaks of a file are a wrong area, an extra or missing field, a wrong kind, a `type:` that the model does not define, a wrong part, part value, link or citation, a link to no file, and a whole that is part of itself. The breaks of the model are a parent, part or citation type that it does not define, and an `is_a` cycle. A citation is a relative Markdown link in the body to a file of the KB. The `is_a` chain and the part chain are followed as deep as the count of types and of files, so no limit cuts a real chain.
- 🚀 **R15. Links and inheritance first:** [implement] The references, the inheritance and the links between objects matter most. Their rules are built and tested first, before the fields of one object, and this order wins over R4 of the parent. The check of the public mark waits, as R4 says. *(the user, 2026-11-20)*
- ✅ **R16. No object without a reference:** [implement] Each staging and consolidated object links to at least one other object, by a citation, a part or a link. Through its links, it reaches a file of the source area, typed or not. An object that reaches none is a break of the drift check. *(the user, 2026-11-20)*
- 🚀 **R17. A first model, food first:** [implement] For a KB with no model, the script writes a first model from the frontmatter of its pages, after the move of `plans/food/components/food-layout/`. The script writes it into the KB, and Claude commits it on the `main` of that KB. After that, the user edits the model, and the script never writes it again. The food domain of `personal` gets its model first. A field with numbers on some pages and text on others gets the kind text. A test copies the food domain into a throwaway folder, changes one rule of its model, and sees the check name each food page that breaks.
- 🚀 **R18. The model for the picture:** [implement] The script prints the types of the KB model as JSON, and `kb-types.py` reads it to draw the map and the flow. So the picture shows the model, not a reading of the pages.

## Open questions

- ✅ Is a field that is not public a value the model holds for the object, such as a count or a total that a script works out, and that no page writes? Claude reads "some of the things that should be exposed to user are marked as public" this way.
  > **For:** R4, what a field with no public mark is.
  > **Why it matters:** a value with no place in a page needs another store, or a script that works it out on each run.
  > **Why now:** `p-design` models R4 and R14 from the answer.
  > **Pros of a worked-out value:** the page stays short, and the model still names the field and its kind.
  > **Cons of a worked-out value:** each such field needs a script that fills it.
  > **Pros of a field the user does not see:** it can still sit in the page, hidden from the map.
  > **Cons of a field the user does not see:** two kinds of frontmatter key, which is harder to read.
  > **Fern:** not asked, because only the user knows what he meant.

  Recommendation: a worked-out value. A page writes only public fields, and the model names the rest with their kinds.

  Answer: the public mark is not important. The references, the inheritance and the links are. Claude takes the recommendation. the user, 2026-11-20.
- ✅ Does "no reference" mean a staging or consolidated object that links to no other object? Claude reads the user's "if no reference that is actually a no no" this way, and R16 says it.
  > **For:** R16, which objects must have a reference.
  > **Why it matters:** the drift check fails each object the rule covers.
  > **Why now:** `p-design` models R16 from the answer.
  > **Pros of links out:** a staging or consolidated page always says where it came from, as the source, staging and consolidated areas need.
  > **Cons of links out:** a source file that nothing cites still passes.
  > **Pros of links in too:** a source that no page uses shows up.
  > **Cons of links in too:** each new source breaks the check until a page cites it.
  > **Fern:** not asked, because only the user knows what he meant.

  Recommendation: links out only. A source that nothing cites is listed, and it is not a break.

  Answer: links out only. Claude takes the recommendation, as the user asks in a spec run. Claude, 2026-11-20.

## Research questions

### the user

TBD

### Claude

TBD
