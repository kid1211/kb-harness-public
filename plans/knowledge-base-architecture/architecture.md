```graph
begin start
end written raised
fail refused flagged
external media-icloud-sync op-fork-new-wt kb-object-model
skill kb_guard kb_after kb_check
start: Claude is about to write one file in a KB
start.run: kb_guard
which-tool?: Does Claude write with Write or Edit, which the hook sees, or through Bash, which it does not?
which-area?: Which area does the name give? A .source. or .staging. suffix, a plain .md, or a file outside the KB
dating: The file is source. The hook checks its event date, and that it is new
dating.run: kb_guard, kb_check
free: The file is staging. Claude writes it with no approval
free.run: kb_guard
comparing: Claude compares what it wrote with the consolidated page of the topic
comparing.run: kb_after
conflict?: Does the new staging text disagree with a confirmed fact?
asking: The file is a consolidated page. The hook builds the page as it will be, and checks it
asking.run: kb_guard, kb_check
complete?: Does the page as it will be have the user's score at its root and a source for each fact?
user-yes?: the user sees the change in the permission prompt. Do they say yes?
written: The file is written. The check finds its area, date and score in order
raised: A TODO(P1) marker in staging names the conflict. The user is told. The page is as it was
refused: The write does not happen. The hook names what is missing: a date, a score, a source or a yes
flagged: A Bash write skipped the check. The PostToolUse hook names each KB file it changed
kb_guard: The PreToolUse hook kb-guard.sh
kb_after: The PostToolUse hook kb-after.sh
kb_check: The script kb-check.py, which holds every file rule
media-icloud-sync: The skill that keeps photos, PDFs and private files out of git, in iCloud, behind a symlink
op-fork-new-wt: The skill that opens a fork session, where the user settles a conflict
start -> which-tool?
which-tool? -> which-area? [Write or Edit], flagged [Bash, a KB file], written [Bash, not a KB file]
which-area? -> dating [.source.], free [.staging.], asking [plain .md], written [exempt: CLAUDE.md, plans/]
dating -> written [dated and new], refused [no date, or an old source file without the user's yes], media-icloud-sync
free -> comparing
comparing -> conflict?
conflict? -> raised [yes], written [no]
raised -> op-fork-new-wt
asking -> complete?
complete? -> user-yes? [yes], refused [no: score or source missing, the user not asked]
user-yes? -> written [yes], refused [no]
kb-object-model: components/kb-object-model/ the types of each page, read from its frontmatter, and the map
kb-object-model -> kb_check [the types]
```
