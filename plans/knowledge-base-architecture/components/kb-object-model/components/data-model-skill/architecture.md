```graph
begin start
end shown
fail no_domain bad_model bad_graph
skill kb_design draw_graph
hook check-folders
external kb_model_py page_py folders_py
kb_design: the skill kb-design, which keeps the data model of a domain with the user
draw_graph: the skill draw-graph, whose graph text the page uses
kb_model_py: the drift check kb-model.py, which reads the model and checks the files
page_py: the script page.py of the skill, which writes the page from the types of the model
folders_py: the script folders.py of the skill: each folder of the domain holds one type, by its name
check-folders: the hook of the skill, which runs folders.py after each write into the KB
start: The user names a domain of a KB and says what it holds, or what to change
domain?: Does the domain have a CLAUDE.md in a KB with a kb-model.qnt?
reading: Claude reads the domain CLAUDE.md, the types of the model and the page of the domain
writing_model: Claude writes the types of the domain into kb-model.qnt, each with a comment that says what it holds
model_ok?: Does kb-model.py read the types of the model?
drawing: page.py writes kb-model.staging.md next to the domain CLAUDE.md, from the types of the model
graph_ok?: Does the graph check check.js of draw-graph pass the page?
shown: Claude runs the drift check and the folder check, names each break, and links the page
no_domain: No such domain, or its KB has no model. Claude says which, and writes nothing
bad_model: The model fails in Quint. Claude puts the model back and shows the error
bad_graph: The page breaks a rule of the graph check. Claude shows the rule
start.run: kb_design
reading.run: kb_design, kb_model_py
writing_model.run: kb_design
drawing.run: page_py, draw_graph
shown.run: kb_model_py, folders_py
start -> domain?
domain? -> reading [yes], no_domain [no]
reading -> writing_model
writing_model -> model_ok? [model written], check-folders
model_ok? -> drawing [yes], bad_model [no]
drawing -> graph_ok? [page written]
graph_ok? -> shown [yes], bad_graph [no]
shown -> reading [the user asks for a change]
```
