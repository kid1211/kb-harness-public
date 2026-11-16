# Knowledge base architecture: detailed requirements

## Requirements

- 🚀 **R1. Research first:** [research] Find what people do with a KB or second brain, before LLMs and after them. Cover folder structure, flat or nested, staging, consolidation, kinds of information, metadata, links, tags, time and confidence. For each practice, give what people say and a verdict for this KB: adopt, too much work for the gain, or no gain.
  - Serves: F4
- 🚀 **R9. Three areas in each topic folder:** [implement] Each topic folder, such as `member/colon-issue/`, holds its source, staging and consolidated files side by side, with no sub-folder per area. A dot suffix before the extension names the area: `name.source.<ext>` is source, photos and PDFs too, and `name.staging.<ext>` is staging. A `.md` file with no suffix is consolidated.
  - Serves: F1
- 🚀 **R21. Source records when it happened:** [implement] Source stays as it came in: a photo, a scan, an export, OCR text, a fact the user tells. Its name, or its folder's name, gives the date of the real-world event, as far as the user knows it. A check flags a source with no date, and lists the ones whose date is not known.
  - Serves: F2
- 🚀 **R4. Every claim links to source:** [implement] A page in staging or consolidated links each fact to its source file. The user can open the source in one click and check it against the real world.
  - Serves: F2
- 🚀 **R12. Staging is Claude's area:** [implement] Claude can index, re-index, cross-check and research in staging with no approval. `p-research` writes its research into the staging of the topic it serves. The user does not need to read staging.
  - Serves: F1
- 🚀 **R22. The user's confidence on each heading:** [implement] A consolidated page says what is true now, and git holds its history. The user confirms it with a confidence score and the date they confirmed it. A heading with no score takes its parent's. A fact the user doubts, or has not checked, stays in staging. A check flags a consolidated page with no score.
  - Serves: F3
- 🚀 **R7. A conflict goes to the user:** [implement] If Claude finds that staging or new source conflicts with a consolidated page, Claude does not edit the page. Claude tells the user and proposes a fork session to settle it.
  - Serves: F3
- 🚀 **R28. Skills know the layout:** [implement] One KB skill with hooks replaces `read-from-kb` and `trigger-kb-adoc`. `p-research` reads the KB by this layout, checks consolidated first, then researches online and compares. Each other skill that saves a file into a KB names it by the layout: a dated `.source.` file, or a `.staging.` page.
  - Serves: F4
- 🚀 **R23. Mark what is missing where it is missing:** [implement] the user and Claude mark information a page misses, to gather or to make, under its heading, with a priority. Claude marks staging pages only, and the user's priority wins. One command lists every mark of a KB, highest priority first.
  - Serves: F3
- 🚀 **R24. One check, shared:** [implement] One script holds every KB file check: area, date, score and sources. The `kb` hooks and `p-research` call it, and none of them copies one. It prints one line per problem, so a caller can add the lines to its own report.
  - Serves: F4
- 🚀 **R25. Recheck on demand:** [implement] the user can recheck at any time. A whole-KB check applies every check of R24 with no LLM. It also lists each consolidated page changed outside the hook. A topic recheck has a fresh agent compare staging, and source newer than the confirmed date of R22, with the consolidated pages. Each conflict becomes a high-priority mark (R23).
  - Serves: F4
- 🚀 **R27. The layout grows folder by folder:** [implement] No move brings today's files into the layout. The hooks act only on the folders in a list, and the user adds a folder when it follows the layout. A whole-KB check may fail on folders not in the list. No page counts as confirmed until the user confirms it.
  - Serves: F4
- 🚀 **R29. Research runs in a staging folder:** [implement] a domain can hold a `staging/` folder, with one folder per research run, `staging/<YYYY-MM-DD>-<slug>/`. Each run folder holds the `.staging.md` pages of that run. It is the one case of a sub-folder for an area, for research only: it adds to R9 and R12. `p-research` writes there (`p-research` R236). The user reads and rates each answer there (`p-research` research R184). *(the user, 2026-10-24)*
  - Serves: F1
