```graph
begin start
end clean skipped drawn mapped
fail broken bad_table
skill kb_types
external kb-model personal-model data-model-skill
kb-model: components/kb-model/ the Quint model of each KB, and its drift check
personal-model: components/personal-model/ the object model of the personal KB
data-model-skill: components/data-model-skill/ the skill that designs the data model of each domain with the user
start: kb-types.py starts: a check or a draw of one domain, or the map of every KB
start.run: kb_types
mapped: The script read each KB on the roots list, and wrote a map page next to each root CLAUDE.md
has_table?: Does the domain's CLAUDE.md hold a Types table?
reading: The script reads each row of the Types table into a type
reading.run: kb_types
table_ok?: Does each row parse, with known field kinds, and name only types of the table?
matching: Each page gets the type of the first row it matches, or is untyped. Typed pages are tested
matching.run: kb_types
any_break?: Did a typed page lack a field, have a wrong kind or area, lose a part or link, or sit in a cycle?
drawing: The script writes one block of OOP classes: types, fields, is a, made of, links to
drawing.run: kb_types
clean: Every typed page fits its type. The script lists the untyped pages, prints ok and exits 0
broken: The script prints one line per break, with the page and its type, and exits 1
skipped: The domain has no Types table. The script says so and exits 0
bad_table: The Types table itself is wrong. The script names the row and exits 2
drawn: The graph block is printed, for the picture page next to the root CLAUDE.md
kb_types: The script kb-types.py of the kb skill, with its check and draw commands
start -> has_table? [check or draw], mapped [map], drawn [draw, typed pages]
has_table? -> reading [yes], skipped [no]
reading -> table_ok?
table_ok? -> matching [yes, check], drawing [yes, draw], bad_table [no]
matching -> any_break?
any_break? -> broken [yes], clean [no]
drawing -> drawn
```
