# KB model: designs not chosen

- **Quint types for each type of the KB**, such as `type Food = { shelf_life: int }`. Not chosen: a Quint type cannot point at another object, has no inheritance and no optional field, and stops at the first error. The types are data, and the rules are functions.
- **JSON Schema per type, with a lint.** Not chosen: a second tool next to Quint, and a rule across files needs code of its own. See Q3 of the research.
- **LinkML.** Not chosen: a Python stack to install, and a second tool next to Quint.
- **The script checks the rules in Python, and Quint only holds the model.** Not chosen: the rules would then live in two places, the model and the script. Quint runs the rules, and the script only reads files and prints.
- **An `is_a` fold of 8 levels**, as in the proof of concept. Not chosen: a real chain could be deeper. The fold runs as many times as there are types, and the part fold as many times as there are files.
- **A prefix with the domain for a clashing type name.** Not chosen: each page says `type:` with no prefix, so each page of a renamed type would be an unknown type.
- **One fixed `kb-files.qnt` next to the model.** Not chosen: two sessions that check at once would write the same file. Each check uses a temp folder.
- **A typecheck of the model and the file data before Checking.** Not chosen: the file data does not exist before Checking. A failure of the file data goes from Checking to Bad_model.
