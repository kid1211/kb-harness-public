# KB model: design

## State transitions

The model is [kb-model.qnt](kb-model.qnt). Module `kbModelRules` holds the types as data and the rules as pure functions: it is the design of `.claude/lib/kb-model/kb-model-rules.qnt`. Module `kbModelRuleCases` has one bad file per rule. Module `kbModelRun` is one run of `kb-model.py`.

```graph
import-graph: architecture.md
```

1. [Start](#start): `kb-model.py init|check|types <KB root>` starts. Nothing is read yet.
2. [First_model](#first_model): `init` on a KB with no `kb-model.qnt`.
3. [Kept](#kept): `init` on a KB that has a `kb-model.qnt`.
4. [No_model](#no_model): `check` or `types` on a KB with no `kb-model.qnt`.
5. [Bad_model](#bad_model): the model does not typecheck, or the file data fails in Quint.
6. [Checking](#checking): `check`, and the model typechecks.
7. [Drifted](#drifted): at least one rule found a break.
8. [Clean](#clean): no rule found a break.
9. [Exported](#exported): `types`, and the model typechecks.

## The model of a KB

A KB model reads like classes: a type is a class, a file is an instance. It is static types plus rules, as a database has a schema plus foreign keys.

- **The file.** `kb-model.qnt` next to the root `CLAUDE.md` of the KB. It imports the rules file `.claude/lib/kb-model/kb-model-rules.qnt`, through the `.claude/lib` link of the KB, and holds one `pure val types: str -> ObjType`. Each type name is unique in the KB, so two domains never share one.
- **A type** is a record: its areas, its `is_a` parent, its fields, the types it is made of, part of and links to, the part value fields, such as `grams`, and the types its pages may cite. A type gets the fields of each type over it. Its relationships are its own: a type does not get them by `is_a`, but a page of a lower type fits a relationship that names a type over it.
- **One name, one type.** A type name is one name across the KB, so pages of two domains with one `type:` are pages of one type.
- **A field** has a name, a kind (`Text`, `Number`, `Score`, `Day`, `ListOf`), a required mark and a public mark. The public mark is kept but not checked yet. A `Text` field or part field takes a value of each kind, as `kb-types.py` does. A type gets the fields of each type over it, and a field that a lower type declares again wins, as an override does in OOP.
- **A link** is a path. The rules look up the file at that path and test its type. Quint types cannot point at another object, so a reference is a rule, as a foreign key is.
- **Source files.** A source file is never edited, so the model holds `pure val sources: Set[Pattern]`, each a type and a file pattern. The script matches each file of the source area against it. A file that is not `.md` or `.adoc`, such as a photo, is in the source area, typed or not.
- **The file data.** On each check, the script makes a temp folder, copies the model and the rules file into it, and writes `kb-files.qnt` there. It holds one `File` record per typed file, per file a typed file reaches, and per file that says it is part of one. An untyped file out of that set has no break and changes none. Two sessions that check at once do not share a file. Each record holds the path, the area from the name, the type, each field with the kind of its value, the parts with their values, `part_of`, `links_to`, and each citation.
- **The readers.** The script uses the readers of `kb-types.py`: `frontmatter`, `key_lines`, `file_type` and the `LINK` pattern. A field is a frontmatter key or a `- Key: value` line before the first `##`. The script reads the value of a key line by its own pattern, since `key_lines` gives the names only. The keys `type:`, `is_a:`, `part_of:`, `made_of:` and `links_to:` are no fields. A part line is `- <link> grams=400`. A citation is a relative Markdown link in the body to a file of the KB.
- **The kind of a value.** A value that parses as a number is `Number`. A value of 1 to 5 for a field of kind `Score` is a `Score`. `YYYY-MM-DD` is `Day`. A list is `ListOf`. Else `Text`.
- **The check module.** `kb-files.qnt` holds module `kbCheck`. It imports the rules and the KB model, and holds `pure val files`, `var breaks`, `init` as `breaks' = allBreaks(types, files)`, a `step` that keeps it, and `val noDrift = breaks == Set()`. The script lists the untyped files from its own file list.
- **The first model.** `init` takes the types from the `type:` of the pages, and the fields from the pages of each type. A field is required when every page of its type has it. A field with numbers on some pages and text on others is `Text`. `is_a` and the relationships come from the pages too. Each field gets the public mark. A check right after `init` can still break, such as a link to the wrong type: each break shows what to fix. The source patterns come from the `## Source types` table of each domain `CLAUDE.md`, the one place they sit now.

## State deep dive

### Start

The script gets a command and a KB root. It reads no file yet.

**Invariants:** none of its own: each move out of it is guarded by the command and the model file.

**Expected output:** nothing.

### First_model

The KB has no `kb-model.qnt`, and the command is `init`. The script writes the first model from the pages. Claude commits it on the `main` of the KB. The move is `toFirstModel`, and `firstModelTest` runs it.

**Invariants:** `neverOverwrite`.

**Expected output:** `<KB>/kb-model.qnt`, and the line `wrote <path>: <n> types`. Exit 0.

### Kept

The KB has a model, and the command is `init`. The script writes nothing. The move is `toHasModel`, and `keptTest` runs it.

**Invariants:** `neverOverwrite`.

**Expected output:** the line `kept <path>`. Exit 0.

### No_model

The command is `check` or `types`, and the KB has no model. The move is `toNoModel`, and `noModelTest` runs it.

**Invariants:** `exitFits`.

**Expected output:** `no model: run kb-model.py init <KB>` on stderr. Exit 2.

### Bad_model

`npx quint run` fails on the model when the script reads its types, or on the file data in Checking. The moves are `toBadModel` from Start and `toBadData` from Checking. `badModelTest` and `badDataTest` run them.

**Invariants:** `exitFits`.

**Expected output:** the Quint error as it is. Exit 2.

### Checking

The script writes `kb-files.qnt` and runs `npx quint run --main=kbCheck --max-steps=0 --max-samples=1 --out-itf=<file>`, with no invariant. It reads the breaks from the ITF trace, which is JSON. The script lists the untyped files itself. The move into it is `toChecking`. The rules are tested on the files of `kbModelRuleCases`, and on the model `cyclic`, which has an `is_a` cycle.

**Invariants:** `noDrift` and `untypedNoBreak` on good files, `eachRuleFiresTest` and `modelBreaksTest` for the rules.

**Expected output:** the breaks, as a set of `{ path, why, about }`.

### Drifted

At least one break. The move is `toDrifted`, and `driftedTest` runs it.

**Invariants:** `exitFits`, `breaksFit`.

**Expected output:** one line per break, `<path>: <why>: <about>`, sorted by path. Exit 1.

### Clean

No break. The move is `toClean`, and `cleanTest` runs it.

**Invariants:** `exitFits`, `breaksFit`, `untypedNoBreak`.

**Expected output:** one `untyped <path>` line per untyped file, then `ok <KB>`. Exit 0. The run stays here by `stay`.

### Exported

The command is `types`, and the model typechecks. The script runs `npx quint run` on a module that holds `types` and `sources` as state, reads the ITF trace, and prints the types as JSON. `kb-types.py` reads it to draw the map and the flow. The move is `toExported`, and `exportedTest` runs it.

**Invariants:** `exportNeedsModel`.

**Expected output:** one JSON object: each type name with its areas, parent, fields and relationships. Exit 0.

## Build checks

The level builds two files of the harness library: the script `kb-model.py` and the Quint file `kb-model-rules.qnt`. The script uses the readers of `kb-types.py` in the `kb` skill. The parent level names the script in the `SKILL.md` of the skill.

- **Unit tests:** `python3 -I .claude/lib/kb-model/kb-model.py --test`. Each case runs in a throwaway folder:
  - one test per state: `first_model`, `kept`, `no_model`, `bad_model`, `drifted`, `clean`, `exported`, with the exit code of `exitFits`,
  - `toBadData`: file data that Quint refuses exits 2,
  - `neverOverwrite`: `init` twice leaves the first model as it is,
  - `stay`: a second `check` on a clean KB prints the same lines,
  - `breaksFit`: a KB with no break prints `ok`, and a KB with one prints its line,
  - one test per rule of `eachRuleFiresTest`, on real files in the throwaway folder, each with the line it prints,
  - `noDrift`: the good files of `kbModelRuleCases`, written as real files, print `ok`,
  - `modelBreaksTest`: a model with a name no type defines and an `is_a` cycle prints each model break,
  - `exportNeedsModel`: `types` on a KB with no model or a bad one prints no JSON,
  - `untypedNoBreak`: a photo with no pattern and a page with no `type:` are listed, not breaks,
  - `Pattern`: a photo that matches a pattern gets its type, and one that matches none is untyped,
  - the readers: a key line is a field, a part line gives its values, a body link is a citation, a link out of the KB is none,
  - the first model: a mixed field is `Text`, a field on every page is required,
  - a `Text` field with a number or a date value is no break,
  - two files that are part of each other by `part_of:` lines are each "part of itself",
  - R17: a copy of the food domain, one rule changed, names each food page that breaks.
- **The rules file:** `kb-model-rules.qnt` holds the modules `kbModelRules` and `kbModelRuleCases` of the model as they are. `npm run check` runs its tests, `eachRuleFiresTest` and `modelBreaksTest`, and the negative control `noDriftNegative` must fail.
- **A state check:** after `init`, the KB holds `kb-model.qnt` and nothing else new. After `check`, it holds nothing new.
- **No check can see:** that the first model names the types the user means. the user reads it after `init`.

## Coverage

| Requirement | Held by |
|---|---|
| R4 | waits: the user deferred the check of the public mark. The model keeps the mark on each field, and no rule reads it |
| R5 | `untyped`, `untypedNoBreak`. The model types each pattern by `Pattern`, and the script matches it, since Quint has no string match |
| R19 | `lineage`, `isA`, `allFields`, the rules as pure functions of `kbModelRules` |
| R13 | `modelBreaks` and `fileBreaks` read each part of a type: areas, parent, fields, relationships, part fields and citations |
| R21 | `allBreaks`, `drift`, `fileBreaks`, `modelBreaks`, `children`, `eachRuleFiresTest`, `modelBreaksTest`, `exitFits`, `breaksFit` |
| R15 | Build checks: the tests of links, parts and the parent chain come first. The order of a build is no state, so the model does not hold it |
| R16 | `linkReach` and the `reaches no source` break of `fileBreaks` |
| R17 | `toFirstModel`, `toHasModel`, `neverOverwrite`; the food test of Build checks |
| R18 | `toExported`, `exportNeedsModel`. The reader of the JSON in `kb-types.py` is built by the parent level, whose `Builds:` line names `kb-types.py`, by its R30 |
| first_model | `firstModelTest` |
| kept | `keptTest` |
| no_model | `noModelTest` |
| bad_model | `badModelTest` |
| drifted | `driftedTest` |
| clean | `cleanTest` |
| exported | `exportedTest` |

## Risks

- **Quint start time.** The proof of concept took about 4 s on the food domain, with no reach rules. The build measures it again. A check on each write is too slow, so the check is a command, not a hook.
- **The size of the KB.** `linkReach` and `partReach` fold as many times as there are files. On a KB of thousands of files, this can be slow. If so, the script splits the check per domain, with the links that cross domains kept.
- **Type names clash.** Two domains can want one name, such as `research`. They then share one type. If they need two, the user renames the type and the `type:` of its pages.
- **The keys that are no fields.** R14 lists four keys, and the design adds `is_a:`, which a page may still write. `p-req` adds it to R14.
- **The public mark waits.** A required field with no public mark would break each page. No such field exists until R4 is built.
- **Guards hold some invariants.** `neverOverwrite` and `exportNeedsModel` restate the guards of their moves. The unit tests of each test the script, where no guard holds them.
- **The JSON export.** The script reads the ITF trace of `quint run`, which is JSON, so no print form of Quint is parsed. Quint is pinned, and the test of `exported` reads a real trace.
- **The source patterns.** They move from `## Source types` in each domain `CLAUDE.md` into the model at `init`. Until R32 of the parent is built, both places exist, and the model wins.

## Appendix

- The research and its proof of concept: `personal/claude-research/staging/2026-11-20-kb-object-quint/kb-object-quint.staging.md`, with `poc-kb-model.qnt`, `poc-gen.py` and `poc-run.sh` next to it. Run `sh <that folder>/poc-run.sh` from the harness root.
- The model checks, from the harness root:

  ```sh
  npx quint typecheck plans/knowledge-base-architecture/components/kb-object-model/components/kb-model/kb-model.qnt
  npx quint test <model> --main=kbModelRuleCases
  npx quint test <model> --main=kbModelRun
  npx quint run <model> --main=kbModelRuleCases --invariant=noDriftNegative --max-steps=0 --max-samples=1   # must fail
  npx quint run <model> --main=kbModelRun --invariant=neverDrifted                                          # must fail
  ```
