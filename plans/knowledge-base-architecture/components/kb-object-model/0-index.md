# KB object model

## Goal

Say how each KB is structured as data objects. A single object, such as one food, has a type and frontmatter fields. Objects group into bigger objects, such as a meal made of foods, and those group again. Each domain declares its types, a check tests each file against them, and a graph next to the KB's root CLAUDE.md shows the picture. The food domain is the first test. Draft.

- The data object comes first.
- A KB level of its own writes the food Types table. One level builds in one repo.
- A run of the script writes the picture page of each KB.

Builds: the type check and picture writer `.claude/skills/kb/scripts/kb-types.py`, its lines in `.claude/skills/kb/SKILL.md`, the list of KB roots `.claude/skills/kb/assets/kb-roots.txt`, the map script `.claude/skills/kb/assets/kb-map.js`, and its test `tests/skills/kb/kb-map.test.js`.
Uses: the draft `personal/kb-structure.md`, the food proposal `personal/food/staging/2026-11-20-food-restructure/food-restructure.staging.md`, the `kb` skill of the parent level, and `plans/food/components/food-layout/`, which moves the food files.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- **F1.** Each object has a type, and its type gives its frontmatter fields. Build this first.
  Decision: pending
  Built: 0 of 4
  What Claude thinks the user means: I want each page to be a typed record, such as a meal with its scores.
- **F2.** Objects group into bigger objects, and those group again.
  Decision: pending
  Built: 0 of 5
  What Claude thinks the user means: I want a meal made of foods, and a plan made of meals, as links.
- **F3.** Each domain declares its types in one place, and a check tests each file against them.
  Decision: pending
  Built: 0 of 0
  What Claude thinks the user means: I want the structure written down once, and a tool to tell me where the files break it.
- **F4.** A picture of the structure, next to the root `CLAUDE.md` of the KB.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: I want to open one page in the preview and see the KB drawn as OOP classes.
- **F5.** The food domain is the first domain and the test.
  Decision: pending
  Built: 0 of 1
  What Claude thinks the user means: I want the food restructure to prove the model, by a check that fails today and passes after the move.
- **F6.** The picture covers every KB. It shows one level up and three down, a click goes into a node, and Show all and Reset sit at the top right.
  Decision: pending
  Built: 1 of 2
  What Claude thinks the user means: I want to click through all of the model.
- **F7.** The fields of an object are its frontmatter, so the model never drifts from the pages. Leave the other domains with no Types table for now. Maybe a field marks an intermediate object.
  Decision: keep
  Built: 0 of 1
  What Claude thinks the user means: I want each page to say its own type and parts in its frontmatter, and the picture read them, not a table kept apart.

- **F8.** Each root folder has the data object picture next to its `CLAUDE.md`, opened on its own level. The picture is only the presentation layer.
  Decision: keep
  Built: 0 of 1
  What Claude thinks the user means: I want to open the map from any domain folder and land on that domain.
- **F9.** A page that fits the data model follows it. Claude backfills a page that does not. Else it sits by itself under miscellaneous, for the user to check and shrink.
  Decision: keep
  Built: 2 of 6
  What Claude thinks the user means: I want one list of loose pages to clean up.
- **F10.** Each KB has its object model in a file of its own, apart from the pages. A map ties each file to its object, and a drift check says where the files and the model differ. A Quint model would be best, so the KB and the plans use one tool. This is for the KB only.
  Decision: keep
  Built: 0 of 9
  What Claude thinks the user means: I want the KB types in a Quint model, and a check that the files still fit it.

- **F11.** Each skill that finds info in a KB, or points at a KB, goes through the KB model. That forces the skills and the KB to stay the same.
  Decision: keep
  Built: 0 of 2
  What Claude thinks the user means: no skill hard-codes where a KB keeps a thing. It reads the model to find the type and its folder.

- **F12.** A skill builds and keeps the KB model with the user. It links an `.md` page that shows him what each type is, and it draws that page by the `draw-graph` skill.
  Decision: keep
  Built: 0 of 1
  What Claude thinks the user means: I don't run scripts or read Quint. I say what the KB holds, the skill writes the model, and I check it in a picture.

## Open questions

- ✅ What does the check do with a page that is no typed object, such as staging research, `needs-words.md` or a photo?
  Answer: it lists the page as untyped. That is not a break. the user, 2026-11-20: some pages have frontmatter and some do not.
- ✅ How do the type check and the `score` and `sources` rules of the parent level fit on one page?
  Answer: `kb-types.py` is its own command, outside `kb-check.py all` and the hooks. A `score` field (1 to 5) is not the `confidence` of the parent (1 to 3). Claude's pick, 2026-11-20.
- ✅ How are part values, such as grams, written and typed?
  Answer: one flat line for each part, `- <link> grams=400`, and a Part fields column in the Types table. Claude's pick, 2026-11-20.
- ✅ Which rule settles a path that matches two collections?
  Answer: the first row that matches wins. Claude's pick, 2026-11-20.
- ✅ How does the picture look?
  Answer: as OOP classes. Each type is a node with its fields, and a type can extend another, drawn as "is a". the user, 2026-11-20.
- ✅ Does the map of each KB show the other KBs, such as `eventPNL`?
  Answer: yes, every KB on a full list of KB roots that the harness keeps. the user, 2026-11-20.
- ✅ What does "a field for intermittent" mean? Claude reads it as an intermediate object, such as a meal between a food and a week plan, marked by a frontmatter field like `part_of:`.
  > **For:** F7, how a page says where it sits in the tree of objects.
  > **Why it matters:** the map and the check read this field. A wrong guess builds the wrong field.
  > **Why now:** p-req writes the F7 requirements from the answer.
  > **Pros of an intermediate object:** it fits "objects group into bigger objects", and each page names its own parent.
  > **Cons of an intermediate object:** it may not be what the user meant, such as intermittent fasting or a field that changes now and then.
  > **Fern:** not asked, because only the user knows what he meant.

  Recommendation: an intermediate object, with `type:` and `part_of:` in the frontmatter of each page.

  Answer: inheritance or relationship. A page says `is_a:` for inheritance, and `part_of:`, `made_of:` and `links_to:` for its relationships. the user, 2026-11-20.
- ✅ major: the state model `kbTypeCheck` skips a domain with no table and does not draw it (`drawnOnlyFromTable`), but `kb-types.py draw` now draws from the pages. `p-design` adds a typed-pages path to the states.
- ✅ minor: in a domain whose pages carry `type:`, the map shows only the types, not the folders of untyped pages, against R14.
- ✅ minor: the script drops a relationship to a missing or untyped page with no message, and two `is_a:` parents of one type keep only the first.
- ✅ Should the Quint model hold the types, while each page keeps its `type:` and links in its frontmatter? F10 asks for a model in its own file. F7 and R17 say the frontmatter is the model. [The research](../../../../../../personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md#q4-does-the-quint-model-replace-the-frontmatter-as-the-model-or-add-to-it) found that a Quint model can check the food pages.
  > **For:** F10 and F7, which say where the types live.
  > **Why it matters:** R17, R20, R21 and R28 change with the answer, and so do the map and the flow.
  > **Why now:** `p-req` writes the F10 requirements from it, and `p-design` waits on them.
  > **Pros of both:** one model file for types and rules. Each page still says what it is, and the check tests it against the model.
  > **Cons of both:** a field sits in two places. A new field needs a model edit first.
  > **Pros of the Quint file alone:** the map and the flow read one place.
  > **Cons of the Quint file alone:** the map hides a field that a page has and the model lacks.
  > **Fern:** not asked, because only the user knows which want wins.

  Recommendation: both. The Quint file is the type source, each page keeps its `type:`, and the map shows the model with each break marked.

  Answer: everything is in the model. The model marks each field that the user sees as public, and a public field sits in the frontmatter of the page. the user, 2026-11-20.
- [How others check a model against files](../../../../../../personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md#q1-how-do-tools-keep-a-data-model-apart-from-its-files-and-check-the-drift) is unsettled. Three tools do it the same way: Astro, remark-lint-frontmatter-schema and LinkML. The remark-lint facts have two sources from one package, and two other sources were not opened again. It needs one more source per fact, from a run of `p-research`. It does not block F10.
- ✅ The `kb-model` component settles four points of the requirements review, and this level needs a round to match them. R30 still checks the public mark, which `kb-model` R4 defers. R24 says each staging and consolidated page cites a source, and `kb-model` R16 says it reaches one through its links. R4 builds one object's fields first, and `kb-model` R15 builds links first. R2 has the kind `link:<type>`, and R36 says a link is no field.
  Answer: R39, R40, R41 and R43 match them now, and R30 no longer checks the public mark. Claude, 2026-11-20.
- ⚠️ The level holds 22 requirements, over the limit of 8. The map and flow requirements, R22, R24, R26, R31, R32, R34, R35, R37 and R38, can move into a component of their own. `p-req` does that split in its next round.
- ✅ minor: R24 of the parent level says one script holds every KB file check. `kb-types.py` adds a second one for types. The parent's R24 needs a line that allows it. The same line allows `kb-model.py`, the drift check of `components/kb-model/`.

## Research questions

### the user

1. open [How do tools keep a data model apart from its files, and check the drift?](../../../../../../personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md#q1-how-do-tools-keep-a-data-model-apart-from-its-files-and-check-the-drift)
2. answered [Can a Quint model hold the KB object model?](../../../../../../personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md#q2-can-a-quint-model-hold-the-kb-object-model)
3. answered [How does a check test the KB files against a Quint model?](../../../../../../personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md#q3-how-does-a-check-test-the-kb-files-against-a-quint-model)

### Claude

1. answered [Does the Quint model replace the frontmatter as the model, or add to it?](../../../../../../personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md#q4-does-the-quint-model-replace-the-frontmatter-as-the-model-or-add-to-it)
