```graph
begin start
end first_model kept clean exported
fail no_model bad_model drifted
skill kb_model
external quint
kb_model: the script kb-model.py of the harness library
quint: npx quint, which typechecks and runs the model
start: kb-model.py starts on one KB, with init, check or types
cmd?: Which command runs?
model_for_init?: Does the KB already have a model?
model?: Does the KB have a model?
typechecks?: Does Quint read the types of the model?
first_model: The script writes a first model from the pages, and Claude commits it in the KB
kept: The KB has a model, so the script writes nothing
no_model: Check and types need a model. The script says so and exits 2
bad_model: The model or the file data fails in Quint. The script prints the Quint error and exits 2
checking: The script writes the files as Quint data and runs the rules of the model on them
any_break?: Did a rule find a break?
drifted: The script prints one line per break, with the path, the rule and what it is about, and exits 1
clean: No break. The script lists the untyped files and exits 0
exported: The script prints the types of the model as JSON, for the map and the flow
start.run: kb_model
checking.run: kb_model, quint
start -> cmd?
cmd? -> model_for_init? [init], model? [check or types]
model_for_init? -> kept [yes], first_model [no]
model? -> typechecks? [yes], no_model [no]
typechecks? -> checking [yes, check], exported [yes, types], bad_model [no]
checking -> any_break? [Quint ran], bad_model [the file data fails]
any_break? -> drifted [yes], clean [no]
```
