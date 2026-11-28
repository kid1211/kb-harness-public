# Writing check: design decisions not chosen

- **The Terms table in the rules file too.** Dropped: `id-hover` and `term-scan.py` read it from `.claude/CLAUDE.md`, and it holds the words of this harness.
- **A public overlay `.claude/CLAUDE.md` with a copy of the rules.** Dropped: two copies of each table drift apart.
- **One graph decision per command.** Dropped: the graph grew too tall to read. The links name the command.
- **A chart note alone blocks the edit.** Dropped after the design review: the note is advice, so it goes as `additionalContext`, as the script does now.
