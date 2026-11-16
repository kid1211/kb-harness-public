```graph
user: The user reads code and Markdown in VS Code
claude: The Claude Code session in the terminal
code-reference: components/code-reference Cmd+Shift+C copies @path#L12-20 of the selected lines
plan-preview: components/plan-preview A plan level in the preview: folded state parts, research answers in a popup, feedback written back
user -> code-reference [selects lines]
user -> plan-preview [reads a plan]
code-reference -> claude [the user pastes the reference]
```
