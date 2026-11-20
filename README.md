# Claude Code harness, public part

Skills, shared libraries and Quint tooling from a private Claude Code harness. A sync script
copies a chosen list of paths here, as a PR into `nightly`. `main` and `nightly` take a change
only by a PR whose checks passed, merged by squash.

The checks on each PR and push scan for PII, secrets and a private list of names, and run the
unit tests of the scans. A PR from a fork cannot pass the name scan, since it gets no secret.

Some files name paths of the private harness that are not in this repo. Those links do not resolve here.

## Multi-folder sessions

One session on several folders, with a map of folder to project and its supporting docs.

- **The map:** a Markdown table with the columns Folder, Project, Role and KB. Copy `projects-mapping.md.template` to `projects-mapping.md` in the harness main checkout. Git ignores it. Set `PROJECT_MAP` to read another file. After each git commit, the `project-map-check` hook names a folder that is on no row.
- **Start:** `bash scripts/project-start.sh <project>` runs `claude` with `--add-dir` for each folder of the project. Or type `/add-dir <folder>` in a session.
- **Hooks:** `.claude/settings.json` wires `add-dir-context.sh` and `nested-instructions.sh`. The first tells Claude the project, role and docs of a folder on the next prompt. The second gives the `CLAUDE.md` files of a subfolder in an added folder, which Claude Code does not load.
- **Status line:** pipe the status line input to `scripts/statusline-folders.sh` in your `~/.claude/statusline.sh`. It prints the added folders by project, and writes the session file that the hooks and the pane read.
- **Pane:** the `folder-pane` mod adds a `folders` button and `/folders`, with the folders by role, the supporting docs and the instructions files loaded.
