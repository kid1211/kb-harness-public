# Data model skill

## Goal

A skill that designs the data model of a KB, one domain at a time, with the user. It writes the types into the kb-model.qnt of the KB, runs the drift check, and draws the model as a graph page next to the domain CLAUDE.md by the draw-graph skill. the user reviews the picture and keeps using the skill to change it until it is what he needs. The page colours each type by its area. Showing or hiding types on the page is the want of `plans/draw-graph/components/graph-filter/`.

Route: poc

Builds: the skill `.claude/skills/kb-design/SKILL.md`, its page script `.claude/skills/kb-design/scripts/page.py`, its folder check `.claude/skills/kb-design/scripts/folders.py`, its hook `.claude/skills/kb-design/hooks/check-folders.sh`, and its tests `tests/skills/kb-design/`.
Uses: the drift check `.claude/lib/kb-model/kb-model.py` of `components/kb-model/`, the skill `draw-graph` and its check `.claude/lib/draw-graph/check.js`, the colour line of `plans/draw-graph/components/graph-colours/`, and the area colours of `.claude/lib/palette/kitchen-sink.md`.

## Architecture

```graph
import-graph: architecture.md
```

## Requirements

the user's words, 2026-11-20: "the goal is to design data model for kb per domain. and the end result should draw the graph and let me review and continue usign the skill to update the graph until we have what i need, note down the coloring and so on". Earlier the same day: "we should build a skill that does this and catpure what is needed... it should have link to a md to show the user what they are (also this should know to use draw graph skill)".

- **F1.** the user says what a domain holds, and the skill writes its types into the `kb-model.qnt` of the KB, one domain at a time.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I talk about the domain, and the skill keeps the model. I never edit Quint.
- **F2.** After each change, the skill writes the page `kb-model.staging.md` next to the domain `CLAUDE.md`, by the `draw-graph` skill, from the model. One node per type, with a name that says what it is and a hover that says what it holds. Links carry no text, and each one goes the way the data flows.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: the picture is the model, drawn so I see what each thing is at a glance.
- **F3.** The text colour of a node gives its area: tan for source, light blue for staging, the default colour for confirmed. The colours sit in the kitchen sink for the user to keep.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I see at once which types are raw, which are drafts, and which are final.
- **F4.** The skill runs the drift check, names each break, and gives the user the link to the page. the user reviews it and uses the skill again, until the model is what he needs.
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: a loop of talk, picture, review, until I say it is right.
- **F5.** The page has the button row of `plans/draw-graph/components/graph-filter/` under its graph, so the user can show a few types and build up. *(the user, 2026-11-20: "where is the list of button at the bottom of the graph? that i can choose toggle to show hide?")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: the data model page always has the show and hide buttons.
- **F6.** Each folder of a domain holds files of one type only, and the folder has the name of its type, one to one. *(the user, 2026-11-20: "the indidivudal fodler should have onlye 1 type of data model, and it should be properly named (best if the dat amodel and the fodler name are 1:1 , dont' see why not")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I open a folder named `cooked-batch` and find only cooked batches, and the model has a type `cooked_batch`.
- **F7.** A test enforces F6: a check script with its own tests, run by a hook of the skill after each write into the KB. *(the user, 2026-11-20: "these need to use test to enforce btw, youcan add this as hook inside of the skill")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: a file in the wrong folder, or a folder no type owns, gets flagged at once, not found later.
- **F8.** The skill is named `kb-design`, in the `kb` series of skills. *(the user, 2026-11-20: "this should be kb-design or something, which should be kb series")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I type `/kb-design food`, next to `/kb`.
- **F9.** A domain holds `raw/<type>/` for source objects, `staging/<type>/` for staging objects, and `index/` for the gold pages. A gold page is one `.md` per thing, with no type in the model. *(the user, 2026-11-20: "i think what we want is raw/xxxx list of data model object, staging /xxx list of data model object then index are just our gold it doens't need model object but it should be individiaul .md", and he picked an `index/` folder for the gold pages)*
  Decision: changed
  Built: 0 of 0
  What Claude thinks the user means: changed by F15, raw has no type folders. I open `food/raw/` and see one folder per kind of raw record, `food/staging/` one per kind of draft, and `food/index/` the pages I trust.
- **F10.** A research run goes to `raw/`, not `staging/`. *(the user, 2026-11-20: "reserach should go to raw btw")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: research is raw material until I confirm it, like a receipt.
- **F11.** A raw type and a staging type can share a name, such as `raw/recipe/` and `staging/recipe/`. The folder has the name only. The identifier in the model adds the area: `raw_recipe`, `staging_recipe`. The display name drops it, and the graph shows the display name, coloured by the area. This holds for each type of the model. *(the user, 2026-11-20: "it is allow to have raw and staiging have the same name, but the identifier should automatically add staging/xxx raw/xxx ... it just in the fodler name no need to have the raw-x and staging- ... when it is shown in the identifier it should have the prefix and the display name should not have those, and the graph should use the display name, but also color accordingly, for al lthe model")*
  Decision: changed
  Built: 0 of 0
  What Claude thinks the user means: changed by F15, only staging has types, so each identifier starts with `staging_`. On the graph I see two boxes named "recipe", one tan and one light blue, and in the model they are `raw_recipe` and `staging_recipe`.
- **F12.** No type of the model is gold. A staging type keeps each version it was suggested in, as a slowly changing dimension of type 2: each version is its own object, with the key of its thing, `valid_from` and `valid_to`, empty for the version in force. An `index/` page shows the latest version. *(the user, 2026-11-21: "honslty nothing should be in gold for data model, we should be more like scd2 and keep track of what has been suggested, and index can see the latest one")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: when you change a recipe, the old one stays in staging with an end date, and the index page shows the new one.
- **F13.** Each type of the model has `created_at` and `updated_at`. *(the user, 2026-11-21: "there should be a created at and last updated at for every model right?")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: every object says when it was made and when it last changed.
- **F14.** Each domain has a miscellaneous type that floats: the data that fits no other type yet. *(the user, 2026-11-21: "there should be a misnaelous that float that are the uncategoriezed data")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: `raw_miscellaneous` in `raw/miscellaneous/`, linked to nothing, for the data that fits no other raw type yet.
- **F15.** Raw has no data model. It is an object store, like S3: each file in its original form, in any folder under `raw/`. Only staging has types. *(the user, 2026-11-21: "all the raw should not need the data model, yo ucan treat it as if it is a unstructre object store like s3 or soemthign jsut keep track of al lthe information in its original form, staging is where we have the data model")*
  Decision: changed
  Built: 0 of 0
  What Claude thinks the user means: changed by F17, raw keeps its types. The graph showed one raw box and the staging types. A receipt photo, a post or a note goes into `raw/` with no fields.
- **F16.** Each staging object links to something in raw. *(the user, 2026-11-21: "all the stagign should link to something in raw")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: each staging type reaches a raw type through its links, such as a grocery list through the plan and the recipe to the recipe source. Each staging object has a `raw` field that lists the raw files it came from.
- **F17.** Raw keeps its types, one folder per type named after it, such as `raw/grocery-receipt/`. What is inside a raw folder is not checked: no field and no format. *(the user, 2026-11-21: "i am okay with those raw categoriezed, we should still ahve the raw data model ... just no field no format, taht is it ... like the ofdler name should match but waht is inside we dont' enforce")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: the graph shows the raw types in tan again, each with arrows into the staging types that read it. A photo, a post or a PDF goes into its raw folder as it is.
- **F18.** The text on each link of the graph names the skill that moves the data along it, such as `food-record-body` from the body scale reading to the body reading. *(the user, 2026-11-21: "the text on the line should be what skill for example body scale reading staging right, it should go to meal plan by X skill")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I read the graph as a pipeline: each arrow says which skill writes the next object, and a link with no skill yet has no text.
- **F19.** The hover of a type gives its fields after its description, such as who and when for a body reading. *(the user, 2026-11-21: "should give me the raw fields after the description no? like who and when and so on no?")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I hover body reading and see "Fields: member, date, time (optional), readings", then a note of the standard fields. A raw type says it has no field.
- **F20.** A raw type can list the attributes it is expected to have, such as `source` for a raw recipe. The hover shows them, and no check enforces them. *(the user, 2026-11-21: "yous hould have expected attribute for the receipee, the source at least")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I hover raw recipe and see "Expected: source", marked as not checked.
- **F21.** The graph can show a file that is not a type, such as the list of recipe sources that a skill pulls from to update the raw recipes. It looks apart from a type, and its name says it is a file. *(the user, 2026-11-21: "you can have an empty linne that comes in or a file (you should indicate it is a file , that kept a list of raw source and we do pulling to updat et he raw receipee")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: a box "file: recipe sources" in the component colour, with an arrow into raw recipe that names the pulling skill.
- **F22.** A hover on the skill name of a link shows the key steps of that skill, as a short numbered list. *(the user, 2026-11-21: "show key feature or the description of the skill when hover the text in the line, exampl ... 1. ocr turn body scale to xxx 2. invoke afu to update the target")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: I hover "food-record-body" and see "1. OCR: turn the scale screenshots into a body reading".
- **F23.** A skill that checks a type, such as ask-antafu that confirms with 阿福 that a nutrition goal is right, shows as its own node apart from the types, with a round trip to the type it checks. The links into the type carry no skill name. *(the user, 2026-11-21: "all three just send to them directly with no askantafu. then have a floating thirdparty like a diffent entity symbo that is round trip which is askantafu to confirm the information correctness")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: an "ask-antafu" node with the skill border, a link "check" from nutrition goal to it and "confirmed" back.
- **F24.** The page draws the types around a center: index types in the middle, then staging, then raw, then the external nodes. A type with more links sits nearer the middle. *(the user, 2026-11-22: "where index is closer to the graph center, and then staging then raw. Then complete external, like the more center the closer, because it likely more important and have more connection")*
  Decision: keep
  Built: 0 of 0
  What Claude thinks the user means: meal and nutrition goal in the middle, the raw types around them, files and ask-antafu at the edge.

## Open questions

TBD

## Research questions

### the user

TBD

### Claude

TBD
