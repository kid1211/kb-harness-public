```graph
begin start
end pass_on draw_row cycle compose toggle_pane close_pane
start.run: writing-mode:SKILL.md
read_modes.run: writing-mode:SKILL.md
start: An event: a draw of the band, a press of a mode button or config, a prompt, or another pane opens
read_modes: Read the modes from the mode file of the machine again.
event?: Which event is it?
survey?: Does a survey hold the band?
pass_on: The mod draws nothing of its own and gives the band the tree of next(e)
draw_row: The mod draws its row on top, with the two mode buttons and config at the right
cycle: The pressed mode moves to the next one.
compose: In casual mode, the mod adds the casual section for replies or docs to the system prompt
toggle_pane: A press of config opens the writing-check pane with the report, or closes it if open
close_pane: The pane of another harness mod opens, so the mod closes its writing-check pane
start -> read_modes
read_modes -> event?
event? -> survey? [draw], cycle [press], compose [prompt], toggle_pane [config], close_pane [another pane opens]
survey? -> pass_on [yes], draw_row [no]
```
