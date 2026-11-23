# KB object model: design

## State transitions

The model is [kb-object-model.qnt](kb-object-model.qnt). Module `kbObjectData` is the data object: a type, its fields, its parent type, its parts and links, and the breaks one object can have. Module `kbTypeCheck` is one run of `kb-types.py`. Module `kbMapView` is the map page: the focus, and what shows.

```graph
import-graph: architecture.md
```

1. [Start](#start): `kb-types.py check <domain>`, `kb-types.py draw <domain>` or `kb-types.py map` starts. Nothing is read yet.
2. [Reading](#reading): the domain's `CLAUDE.md` holds a `## Types` table, and the script reads its rows.
3. [Matching](#matching): the table is good and the caller asked for a check. Each page is matched to a type, or listed as untyped. Each typed page is tested.
4. [Drawing](#drawing): the table is good and the caller asked for the picture.
5. [Clean](#clean): each typed page fits its type.
6. [Broken](#broken): at least one typed page breaks its type.
7. [Skipped](#skipped): the domain has no `## Types` table.
8. [Bad_table](#bad_table): the table itself is wrong.
9. [Drawn](#drawn): the OOP graph block of the types is printed.
10. [Mapped](#mapped): each KB of the roots list has its map page.

## The data object

This is the data structure, built first (R4). It reads like classes in OOP: a type is a class, an object is an instance, a field is an attribute.

- **Levels.** KB, domain, collection, object. A domain is a folder with its own `CLAUDE.md`. A collection is a folder and a name pattern that holds the objects of one type. A field is a part of an object, not a level.
- **Object.** One page or record. Its type comes from the first row whose collection its path matches. A page that matches no row is untyped: it is listed, not a break. Some pages have frontmatter and some do not.
- **Area.** The script strips `.source.` or `.staging.` from the name before it matches, and checks the area against the Areas column. So `meals/staging/<name>/<name>.md` matches `meals/staging/鸡/v1.staging.md`.
- **Field.** One flat `key: value` line of frontmatter. Each field has a kind: `text`, `number`, `score` (1 to 5), `date`, `list` (a run of `- ` lines), or `link:<type>`. A `!` after the kind marks a required field. A link field is checked like a `links` entry.
- **Is a.** A type can extend one other type. It gets each field of its parent and adds its own. The parent can extend another type in turn.
- **Made of.** A whole lists its parts under `parts:`, one flat line each: `- ../pantry/items/南瓜.md grams=400`. The `key=value` pairs after the link are the part values. A part stays its own page.
- **Links to.** A list under `links:`, each line a relative link.
- **The Types table.** One `## Types` table in the domain's `CLAUDE.md`. A row reads like this:

  | Type | Is a | Collection | Areas | Made of | Part fields | Links to | Fields |
  |---|---|---|---|---|---|---|---|
  | item | | `pantry/items/<name>.md` | consolidated | | | | `for: text!`, `why: text!`, `buy_every_days: number`, `fresh_days: number!`, `storage: text!`, `keeps: text!` |
  | version | | `meals/staging/<name>/<name>.md` | staging | item | `grams: number!` | | `fullness: score!`, `nutrient: score!`, `easy: score!`, `like: text`, `notes: text`, `good_for: list`, `prep_min: number` |
  | meal | version | `meals/<name>.md` | consolidated | item, meal | `grams: number!` | version | |

  `<name>` matches one path part. `<date>` matches an ISO date. The first row that matches a path wins, so a dated pattern goes above a `<name>` pattern in the same folder.

## The map page

`kb-types.py map` reads `.claude/skills/kb/assets/kb-roots.txt`, one KB folder for each line, such as `~/second-brain/personal`. For each KB it builds one tree:

- Level 0, all KBs. Level 1, each KB. Level 2, each domain: a top folder with a `CLAUDE.md`.
- Level 3, each collection: a row of the domain's `## Types` table, or, in a domain with no table, each folder by its path.
- Level 4, each field of a type, with its kind.

It writes one page for each KB, `<KB>/kb-map.html`, next to the root `CLAUDE.md`. The page holds the tree as a JSON block and the script `.claude/skills/kb/assets/kb-map.js`, copied in, with no file to fetch, so the host server can send it. It opens with the focus on its own KB.

- **Focus.** The page draws the focus, its parent, and each node up to three levels under it (`shown`, by `under`). A click on a node makes it the focus (`click`).
- **Show all.** A button at the top right draws every node of every KB (`showAll`).
- **Reset.** A button at the top right puts the focus back on the page's own KB (`reset`).
- **Look.** Colours and marks come from `.claude/lib/palette/kitchen-sink.md`, in the dark theme.

## Types from the frontmatter

Module `kbFrontmatter` is the model read from the pages alone. Each page says its own type in its frontmatter, so no table can drift from the pages.

- `type:` names the type of the page. A page with no `type:` is untyped (`types`).
- Each other key of the frontmatter is a field. The fields of a type are the keys of each page of that type (`typeFields`).
- `is_a:` names the parent type, drawn as "is a".
- `part_of:`, `made_of:` and `links_to:` hold links to other pages. Each link draws a relationship from the page's type to the type of the page it links to (`typeOf`, `rels`).

`kb-types.py draw <domain>` and `kb-types.py map` read the pages when the domain has no `## Types` table. A domain with a table keeps it until its pages carry `type:`. The map shows each relationship as a node under its type, such as `made of food`.

## State deep dive

### Start

The script gets a command, `check` or `draw`, and a domain folder (`startAs` in the runs). It reads the domain's `CLAUDE.md`. Each end state keeps itself by `stay`.

**Invariants:** `skippedOnlyWithoutTable`.

**Expected output:** none yet.

### Reading

Each row of `## Types` becomes a type: its parent type, its collection pattern, its areas, its parts with their part fields, its links, and its fields with kinds.

**Invariants:** `badTableStops`.

**Expected output:** the list of types, in memory.

### Matching

The run is here after `toMatching`. Each page of the domain gets the type of the first row that matches its path, or goes on the untyped list. The script tests each typed object (`fits`): its required fields, its own and its parents' (`missing`, `allFields`), the kind of each value (`wrongKind`), its area (`areaOk`), each part value (`badPartVals`), each part and link (`lostLinks`), and cycles (`inCycle`).

**Invariants:** `fitHasEachRequired`, `inheritedFieldRequired`, `lostPartFound`, `selfPartIsCycle`, `untypedNotABreak`.

**Expected output:** the set of breaks, and the untyped list.

### Drawing

The script writes one ```` ```graph ```` block, drawn like OOP classes. Each type is a node. Its description lists its fields, such as `fullness: score!, nutrient: score!`. Each parent is a link with the text `is a`. Each made-of is a link with `made of`, and each links-to a link with `links to`.

**Invariants:** `drawnOnlyFromTable`.

**Expected output:** the graph block text.

### Clean

Each typed page fits. The script lists the untyped pages, prints `ok <domain>` and exits 0.

**Invariants:** `cleanOnlyIfAllFit`, `untypedNotABreak`.

**Expected output:** the untyped lines, then `ok <domain>`, exit 0.

### Broken

The script prints one line per break: `<path>: <type>: <kind>: <what>`, such as `food/pantry/items/南瓜.md: item: field: fresh_days missing`. It exits 1.

**Invariants:** `brokenNamesEach`.

**Expected output:** the break lines, exit 1.

### Skipped

The domain has no `## Types` table. The script prints `skip <domain>: no Types table` and exits 0.

**Invariants:** `skippedOnlyWithoutTable`.

**Expected output:** the skip line, exit 0.

### Bad_table

A row of the table does not parse, names an unknown kind, or names a type not in the table, also as a parent. The script names the row and exits 2. It tests no page.

**Invariants:** `badTableStops`.

**Expected output:** `<CLAUDE.md>: Types row <n>: <what>`, exit 2.

### Drawn

The graph block is printed to standard output. The picture page `personal/kb-structure.md` holds the levels graph, written by hand, and one block for each domain from this output. A draw reaches this state from the table, or straight from start by `toDrawnFromPages` when the pages say their type and no table is wrong.

**Invariants:** `drawnOnlyFromTable`.

**Expected output:** the graph block, exit 0.

### Mapped

The run is here after `toMapped`. Each KB of the roots list has `kb-map.html` next to its root `CLAUDE.md`. The script checks no page.

**Invariants:** `mappedOnlyWhenAsked`.

**Expected output:** one line `map <KB>/kb-map.html` for each KB, exit 0.

## Build checks

`p-build` writes these before the code. They are unit tests in the `--test` of the new script, which `python3 -I .claude/skills/kb/scripts/kb-types.py --test` runs.

1. **Data object first (R4).** One unit test for each of these `run`s of `kbObjectData`: `missingScoreTest`, `wrongKindTest`, `areaTest`, `fitsTest`, `inheritTest`. Each makes the same objects as pages in a throwaway domain.
2. **Grouping.** One unit test for each of `partValTest`, `cycleTest`, `noCycleTest`, and a lost link.
3. **The state check.** One unit test for each `run` of `kbTypeCheck`: `cleanTest`, `brokenTest`, `skippedTest`, `badTableTest`, `drawnTest`. Each checks the exit code and the lines, one line per page.
4. **One test for each invariant:** `fitHasEachRequired`, `inheritedFieldRequired`, `lostPartFound`, `selfPartIsCycle`, `cleanOnlyIfAllFit`, `brokenNamesEach`, `untypedNotABreak`, `skippedOnlyWithoutTable`, `badTableStops`, `drawnOnlyFromTable`.
5. **Matching.** The first row wins, and a `.staging.` name matches the pattern with the suffix stripped.
6. **The food test (R12).** `kb-types.py check food` on the real `personal/food/` lists the pages of `pantry/foods/` and `recipes/` as untyped, and exits 0. After the move of `plans/food/components/food-layout/`, those pages are typed. The second half waits for that move.
7. **The map.** One unit test for `mappedTest` and `mappedOnlyWhenAsked`: a throwaway roots list of two KBs gives two pages, each with both KBs in its tree and its own KB as the home. One test for each `run` and invariant of `kbMapView`: `clickTest`, `resetTest`, `topTest`, `focusWindow`, `showAllShowsAll`, `focusShows`. These load `kb-map.js` in node, by `node --test tests/skills/kb/kb-map.test.js`, against a JSON tree.
8. **The frontmatter.** One unit test in `kb-types.py --test` for each run and invariant of `kbFrontmatter`: `unionTest`, `madeOfTest`, `isATest`, `noDrift` through a draw with no table, and `untypedMakesNoType` through a map with no table.
9. **The document checks.** The `## Types` table of `personal/food/CLAUDE.md` gives no `bad_table` (R11). The page `personal/kb-structure.md` holds each graph block, and the graph check of `draw-graph` passes on it (R10).

No check can see whether the types are the right ones for the user. He reads the picture.

## Coverage

| Requirement | Where |
|---|---|
| R1 | `untypedNotABreak`, `fits`. Build checks 5 for the first row that wins |
| R2 | `missing`, `wrongKind`, `missingScoreTest`, `wrongKindTest`, `fitHasEachRequired`. The kind `link:<type>` is checked as a link, by `lostLinks` |
| R3 | `areaOk`, `areaTest` |
| R4 | Build checks 1: the data object tests come first. Not in the model: it is an order of work |
| R5 | `badPartVals`, `partValTest`, `lostLinks`, `lostPartFound` |
| R6 | `lostLinks` |
| R7 | `reach`, `inCycle`, `cycleTest`, `noCycleTest`, `selfPartIsCycle` |
| R8 | `toReading`, `toSkipped`, `toBadTable`, `skippedOnlyWithoutTable`, `badTableStops` |
| R9 | `toEnd`, `cleanOnlyIfAllFit`, `brokenNamesEach`. One line for each page is in Build checks 3, not in the model |
| R10 | `toDrawing`, `toDrawn`, `drawnOnlyFromTable`, Build checks 7 |
| R11 | Build checks 7. Not in the model: the rows are content |
| R12 | `cleanTest`, `brokenTest`, Build checks 6 |
| R13 | `allFields`, `inheritTest`, `inheritedFieldRequired` |
| R14 | `toMapped`, `mappedOnlyWhenAsked`, `mappedTest` |
| R15 | `shown`, `click`, `focusWindow`, `focusShows`, `clickTest`, `topTest` |
| R16 | `showAll`, `reset`, `showAllShowsAll`, `resetTest` |
| R17 | `typeFields`, `types`, `untypedMakesNoType`, `unionTest` |
| R18 | `rels`, `isATest` |
| R19 | `rels`, `typeOf`, `madeOfTest` |
| R20 | `noDrift`, `pagesDraw`, `toDrawnFromPages`, `pagesDrawnTest`, `drawnOnlyFromTable` |
| mapped | `mappedTest` |
| clean | `cleanTest` |
| broken | `brokenTest` |
| skipped | `skippedTest` |
| bad_table | `badTableTest` |
| drawn | `drawnTest` |

The negative controls are `neverMissing` in `kbObjectData`, `neverBroken` in `kbTypeCheck` `fieldNeverShows` in `kbMapView` and `neverTyped` in `kbFrontmatter`. Each must fail.

## Risks

- **Frontmatter with no YAML library.** The script uses the standard library only. Frontmatter stays flat: `key: value` lines, and `- ` lines under a list key. A part line carries its values as `key=value` pairs. A nested map is a `field` break, not a crash.
- **Two scores.** The parent level's `confidence` is 1 to 3, set by the user on a consolidated page. A `score` field is 1 to 5, a fact of the object. They are different fields. `kb-types.py` is its own command, outside `kb-check.py all` and the hooks, so the two checks do not mix. A typed consolidated page still needs `confidence` when its folder joins the parent's list.
- **The picture page is consolidated.** `personal/kb-structure.md` is a plain `.md` at the KB root, so the parent level's guard asks the user on each write. It holds a `Confidence:` line, and its Sources are the `## Types` tables. Until the user confirms it, the draft stays `kb-structure.md`.
- **A type with no page.** A table can declare a type whose folder is empty, such as `pantry/items/` before the move. That is fine: the check has no page to test.
- **The Types table drifts from the skills.** A food skill can write a page the table does not allow. The check finds it on the next run. A hook on each write is left for later.
- **Depth of is a.** The model follows a parent two levels up. The script follows the chain to the top, and a type that is its own parent is a `bad_table`.

- **A new HTML page.** Each `kb-map.html` is a new page. After the first run, Claude asks the user whether to add it to the host list, by the HTML rules of `.claude/CLAUDE.md`.
- **A big tree.** Show all on a KB with many folders draws many nodes. The page lays them out as a tree with folds, so it stays readable. A fold count is left for the user to tune.

## Appendix

- The draft of the model, with the food types: `personal/kb-structure.md`.
- The food proposal: `personal/food/staging/2026-11-20-food-restructure/food-restructure.staging.md`.
- The review of this design by Frieren, 2026-11-20: each action is in Open questions of `0-index.md`, or fixed here.
