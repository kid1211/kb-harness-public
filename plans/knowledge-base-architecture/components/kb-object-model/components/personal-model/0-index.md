# Personal KB model

## Goal

The object model of the personal KB, as one Quint file in the KB root, written from the structure the user confirmed in personal/kb-structure.md. The drift check of kb-model tests the pages against it. The pages are fixed to fit it later, in their own levels.

Builds: the model `kb-model.qnt` in the root of the `personal` KB.
Uses: the rules `.claude/lib/kb-model/kb-model-rules.qnt` and the drift check `.claude/lib/kb-model/kb-model.py` of `components/kb-model/`, and the structure page `kb-structure.md` of the `personal` KB.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

- ⚪ **R1. The levels:** [implement] The model holds the five levels of `kb-structure.md`: KB, domain, collection, object and field. A collection is the folder and file name of the objects of one type. A field is one line of frontmatter. *(the user, 2026-11-20)*
- ⚪ **R2. The food types:** [implement] The model holds each proposed food type of `kb-structure.md`, with its collection, what it is made of with the part values, what it links to, and its fields. Its area comes from the file name. *(the user, 2026-11-20)*
- ⚪ **R3. Exactly the structure:** [implement] The model holds no type, link or field that `kb-structure.md` does not name. If the page leaves a point open, such as whether a field is required, the point goes to Open questions, not into the model as a guess. *(the user, 2026-11-20)*
- ⚪ **R5. Names that say what a type is:** [implement] Each type has a name of one or more words that says what it is, such as `grocery_receipt`, not `receipt`. *(the user, 2026-11-20)*
- ⚪ **R4. The check is the test:** [implement] `kb-model.py check` on the `personal` KB runs with no Quint error. Each break it prints is a page to fix in the data, not a fault of the model. The pages are fixed later, in their own levels. *(the user, 2026-11-20)*

## Open questions

- Should each member get a page of their own needs? Today one page, `food/health/needs/needs-words.md`, holds the needs of the whole family.
- Do the links from an afu nutrition answer and a body scale reading to member needs stay? `kb-structure.md` does not name them.
- Do the six new names fit: recipe source, afu nutrition answer, recipe version, confirmed recipe, member needs and inventory snapshot?

## Research questions

### the user

TBD

### Claude

TBD
