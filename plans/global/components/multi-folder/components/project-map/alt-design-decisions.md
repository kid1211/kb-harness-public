# Project map: designs not chosen

- **The map as a tracked file in the harness.** Not chosen: the harness goes to the public repo, and the map holds the paths of this machine. The map is a file git ignores instead.
- **The map as the page `claude-research/projects.md` in the `personal` KB.** Replaced on 2026-11-20: the user moved it out, since it is a setting of one machine, not KB content. It is now `projects-mapping.md` in the harness main checkout, which git ignores, with `projects-mapping.md.template` as its tracked start.
- **The map in a person's own domain.** Not chosen: that domain holds a health record. `claude-research/` holds the tooling of the harness.
- **A JSON or YAML file.** Not chosen: The user reads KB pages in the Markdown preview, and a table reads well there. The script parses the table.
