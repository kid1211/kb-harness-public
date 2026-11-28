# Data model skill: designs not chosen

- **A hand-written page.** Claude would write the graph page itself after each change. Not chosen: the page and the model drifted on the first try, with new names and links in the page that the model did not have.
- **A new `about` field in the type record.** The hover would sit in the model as data. Not chosen for the PoC: it changes the rules of `components/kb-model/`, which another level builds. The comment above each type holds it.
- **Groups for the areas.** The first draft put source, staging and confirmed in dotted boxes. The user asked for colour in place of boxes.
- **Fill colour for the area.** The `fill #hex` line of this branch takes a hex value. The text colour line takes a palette name, so the area colour is text.

- **The folder check in the kb guard of the `kb` skill.** Not chosen for the PoC: the user asked for a hook of this skill. The guard runs on each write, so it would catch a write by any skill. It is the next step if a file lands in the wrong folder while this skill is not loaded.
- **A type from the folder alone, with no glob.** Not chosen: `kb-model.py` reads the type of a file from its glob. The check keeps the globs and tests that each glob folder has the name of its type.

- **Raw types, `raw/<type>/`.** Each raw record had a type and a folder of its name, with fields. Replaced on 2026-11-21: the user wants raw as an object store with no data model, and each staging type links to its raw files by a `raw` field.

- **Raw as one object store, with no type.** Any file in any folder under `raw/`, and one raw box on the page with an arrow into each staging type. Replaced on 2026-11-21: the user wants the raw types back, each in a folder of its name, with no field rule.
