# Data model skill: design

## State transitions

The model is [data-model-skill.qnt](data-model-skill.qnt). Module `dataModelPage` holds the page as pure functions of the types of one domain. Module `dataModelRun` holds one run of the skill. Module `dataModelFolders` holds the folder check of `folders.py`.

```graph
import-graph: architecture.md
```

1. [Start](#start): the user names a domain and says what it holds, or what to change.
2. [Reading](#reading): the domain has a `CLAUDE.md`, and its KB has a `kb-model.qnt`.
3. [Writing_model](#writing_model): Claude knows the types to add or change.
4. [Drawing](#drawing): `kb-model.py types` reads the changed model.
5. [Shown](#shown): `check.js` passes the page.
6. [No_domain](#no_domain): no such domain, or no model in its KB.
7. [Bad_model](#bad_model): the changed model fails in Quint.
8. [Bad_graph](#bad_graph): the page breaks a rule of the graph check.

## State deep dive

### Start

The skill starts on one domain of one KB. Nothing is read yet.

**Expected output:** none.

### Reading

Claude reads the domain `CLAUDE.md`, the types of the domain from `kb-model.py types <KB>`, the comment above each type in `kb-model.qnt`, and the page `kb-model.staging.md` of the domain if it exists. A type is of the domain when a pattern of `sources` has a glob under the domain folder.

**Expected output:** none.

### Writing_model

Claude writes the types of the domain into `kb-model.qnt`: for each type, a name of one or more words that says what it is, its areas, what it is made of, what it links to, its fields, and a `// ` comment line right above it that says what it holds. A type gets a pattern of `sources` with its folder and file name.

**Invariants:** none: the model check of the next state tests this state.

**Expected output:** a changed `kb-model.qnt`.

### Drawing

`page.py <KB> <domain>` reads the types JSON of `kb-model.py types` and the comment above each type, and writes `kb-model.staging.md` next to the domain `CLAUDE.md`. It is one graph block in the text of the `draw-graph` skill:

- one node per type of the domain, with the comment as its hover,
- one link per pair of types that name each other, with no text, from the lower area to the higher one, and inside one area from the named type to the one that names it,
- a `color <node> text=tan` line for a source type and `text=light-blue` for a staging type,
- a `label <identifier>: <name>` line for each type, so the node shows its name with no area, in the colour of its area,
- a `filter` line, so the page has the button row of `graph-filter` under its graph,
- under the graph, the open points of the domain that Claude keeps.

**Invariants:** `forward`, `inDomain`, `eachName`, `colours`, `hasFilter`.

**Expected output:** `kb-model.staging.md` next to the domain `CLAUDE.md`.

### Shown

Claude runs `kb-model.py check <KB>` and `folders.py <KB> <domain>`, names each break of the domain, and gives the user the full path of the page.

The folder check reads the types of the domain from the globs of `kb-model.qnt`, with `_` as `-`:

- A domain holds `raw/<type>/`, `staging/<type>/` and `index/`. A raw type has a folder of its name and no field rule: what is inside is not checked.
- The glob of a type starts `<domain>/<area>/<type>/`, such as `food/raw/grocery-receipt/*` or `food/staging/recipe/*`. A gold type is a break.
- A file sits in `raw/<a raw type>/` or `staging/<a staging type>/`, at any depth below it, such as one folder per member. A gold page sits right in `index/`, as one `.md`. The domain root holds only its own files, such as `CLAUDE.md` and this page.
- A research run sits in `raw/research-run/<date>-<slug>/`.
- No type is gold. Each type has `created_at` and `updated_at`. A staging type keeps each version as its own object, a slowly changing dimension of type 2: `key` names its thing, `valid_from` starts the version, and `valid_to` ends it, empty for the version in force. An `index/` page shows the latest version. The check reads the fields from `kb-model.py types`.
- The hover of a type is its comment, then `Fields:` and its own fields, each optional one marked. The standard staging fields are named once, after them. A raw type says it has no field.
- A raw type may list fields, all optional: its hover says `Expected:` with them, and no check reads them.
- The KB model holds `files`: one `{ name, path, into, skill }` per list file that feeds a type, such as the list of recipe sources. The page draws it as an external node with the label `file: <name>` and a link into its type.
- The KB model holds `skills`: one `{ a, b, skill }` per pair of types, the skill that moves the data between them. The page writes it as the text of that link.
- The identifier of a type is its area and its name: `raw_recipe`, `staging_recipe`. The folder has the name only.
- Each staging type reaches a raw type through its links, in any number of steps.
- Each staging type has the standard fields: `created_at`, `updated_at`, `key`, `valid_from`, `valid_to`, and `raw`, the list of raw files the object came from.

The hook `hooks/check-folders.sh` of the skill runs the check on each file written into the KB while the skill is loaded, and shows each break to Claude. A write of `kb-model.qnt` checks the globs of each domain. The user reviews the page in the preview, and asks for a change, which starts Reading again.

**Invariants:** `shownHasPage`, `passMeansInPlace`, `failNamesIt`.

**Expected output:** the break lines and the path, in the reply.

### No_domain

Claude says which is missing: the domain `CLAUDE.md`, or the model of the KB. For a missing model, Claude names `kb-model.py init <KB>`.

**Invariants:** `noDomainWritesNothing`.

**Expected output:** no file.

### Bad_model

Claude puts back `kb-model.qnt` with `git -C <KB> restore`, or deletes a new one, and shows the Quint error.

**Invariants:** `badModelPutBack`.

**Expected output:** the model as it was.

### Bad_graph

Claude shows each rule the page breaks. The page stays, so the user can see it.

**Expected output:** the page and the rule lines.

## Build checks

- **Output check:** `python3 -I .claude/skills/kb-design/scripts/page.py --test`. On the food case:
  - `forward`: each link goes from a lower or equal area to a higher or equal one,
  - `inDomain`: no loop, and no link out of the domain,
  - `eachName`: each pair that names each other has a link, with no text,
  - `colours`: the colour line of each source and staging type,
  - `hasFilter`: the page holds a `filter` line,
  - the hover from the comment, and a pass of `check.js` on the written page.
- **State check:** `python3 -I .claude/skills/kb-design/scripts/page.py --test` also runs the script on a throwaway KB:
  - `shownHasPage`: after a run, the page exists next to the domain `CLAUDE.md`,
  - `noDomainWritesNothing`: a domain with no `CLAUDE.md` exits 2 and writes no page,
  - `badModelPutBack`: a model that fails in Quint exits 2, and the page stays as it was.
- **Folder check:** `python3 -I .claude/skills/kb-design/scripts/folders.py --test`, on a throwaway KB:
  - `passMeansInPlace`: a domain with each glob and file in its place passes,
  - `failNamesIt`: a glob out of place, a gold type, and a file out of place, each print a break and exit 1,
  - `rawTest`: a raw type with no field passes, and a file in a folder of no raw type breaks,
  - `reachTest`: a staging type two links from raw passes, and one with no link breaks,
  - `researchTest`: a research run in `raw/research-run/` passes, and one in `staging/` breaks,
  - `indexTest`: a `.md` right in `index/` passes, and one in a sub-folder of `index/`, or a file that is not `.md`, breaks,
  - `globTest`: a gold type breaks.
  - `fieldsTest`: a type with no `created_at` or `updated_at`, and a staging type with no `key`, `valid_from` or `valid_to`, each break.
- **Hook check:** `bash tests/skills/kb-design/test-check-folders.sh`: the hook blocks a write out of place, with exit 2 and the break, and is quiet on a good write and on a file outside a KB.
- **Steps check:** `bash tests/skills/kb-design/test-skill-steps.sh`: the built `SKILL.md` has one heading per state of the graph, in order, and names `page.py`, `kb-model.py` and the `draw-graph` skill.
- `C flow`: one heading per state node in `SKILL.md`.
- No check sees whether a type name says what it is, or whether the picture is what the user needs. The user judges that.
- Start and Reading leave no file.

## Coverage

| Want | Held by |
|---|---|
| F1 | `toNoDomain`, `toWritingModel`, `toBadModel`, `badModelPutBack`, `noDomainWritesNothing` |
| F2 | `edges`, `toDrawing`, `toBadGraph`, `forward`, `inDomain`, `eachName`, `flowTest` |
| F3 | `colour`, `colours`, and the negative control `pageNegative` |
| F5 | `filterLine`, `hasFilter` |
| F6 | `breaks`, `globOk`, `fileOk`, and the negative control `foldersNegative` |
| F7 | `passMeansInPlace`, `failNamesIt`, the hook check |
| F11 | `globOk`, `sameNameTest`, `labelLines` |
| F20 | `expectedHover`, and the `hover fields` test of `page.py` |
| F22 | `stepNotes`, and the `skill steps` test of `page.py` |
| F23 | `checkEdges`, `checkTest`, and the `check skill` test of `page.py` |
| F24 | `ring`, `ringTest`, and the `ring lines` test of `page.py`. The center layout of `plans/draw-graph/components/graph-center-layout/` draws them |
| F21 | `fileEdges`, `fileTest`, and the `list file` test of `page.py` |
| F19 | `fieldHover`, and the `hover fields` test of `page.py` |
| F18 | `linkText`, `skillText`, `skillTest`, and the `skills` test of `page.py` |
| F15 | changed into F17 |
| F17 | `globOk`, `fileOk`, `fieldsOk`, `rawTest` |
| F16 | `reach`, `reachOk`, `reachTest`, `STANDARD`, `fieldsTest` |
| F12 | `VERSIONS`, `fieldsOk`, `fieldsTest`, `globOk` (no gold type) |
| F13 | `STAMPS`, `fieldsOk`, `fieldsTest` |
| F9 | `areaFolder`, `globOk`, `fileOk`, `indexTest`, `globTest` |
| F10 | `fileOk`, `researchTest` |
| F8 | the steps check: the skill is `kb-design` |
| F4 | `toReading`, `toShown`, `stay`, `shownHasPage`, `shownTest`, and the negative control `neverShown` |
| shown | `shownTest` |
| no_domain | `noDomainTest` |
| bad_model | `badModelTest` |
| bad_graph | `badGraphTest` |

## Risks

- **The hover lives in a comment.** Quint keeps no comment in the types JSON, so `page.py` reads the `// ` line right above each type in the model text. A type with no comment gets its name as its hover.
- **A self link is dropped.** A type that links to itself, such as a snapshot to the one before, shows no loop, since a loop needs text. The comment says it.
- **The model lives in the KB, the rules in the harness.** Until this branch merges, the pre-commit check of the KB cannot load the rules, so the model stays uncommitted. The page commits.
- **The filter lives in draw-graph.** The page only writes the `filter` line. The buttons are the build of `plans/draw-graph/components/graph-filter/`. `page.py --only <types>` still draws only some types.

- **The data does not fit yet.** No domain has `raw/`, `staging/<type>/` or `index/` yet, and the food model has gold types. The first check lists each break, and the move is a later run. Until then the hook flags each write into an old folder.
- **`p-research` still writes to `staging/`.** F10 moves research runs to `raw/research-run/`. The plan of `p-research` must change too, and until it does, each run is a break.
- **The hook runs only while the skill is loaded.** A write by another skill is not checked at once. `folders.py` in Shown catches it on the next run.

## Appendix

- The structure of the KB that the user confirmed: `kb-structure.md` in the `personal` KB.
- The first page, drawn by hand: `food/kb-model.staging.md` in the `personal` KB.
- The colour line: `plans/draw-graph/components/graph-colours/`.
