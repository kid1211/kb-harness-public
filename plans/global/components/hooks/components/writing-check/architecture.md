```graph
begin received
end quiet fed_back reported
fail failed_open failed
external claude_code writing_mode chart-suggest
hook claude_code
received.run: writing-check:writing-check.py
loaded.run: writing-check:writing-check.py
checked.run: writing-check:writing-check.py
claude_code: Claude Code runs the hook after a .md edit (post) and when Claude stops (stop)
writing_mode: The config pane of the writing-mode mod runs the report command
chart-suggest: components/chart-suggest/ Says if a doc should hold a chart, and which, from a scored catalog
received: The script has its command, and the hook input on stdin for post and stop
skip?: A hook in mode off, a skipped or non-.md path, or a stop that blocked once?
rules_ok?: Does the rules file hold its four tables?
loaded: The script has the word tables, and the Terms table and STE data if they are there
checked: Each rule has its score, and a docs table has its chart note if the catalog is there
quiet: The hook exits 0 and prints nothing
failed_open: The hook prints one error line on stderr and exits 0
failed: The command prints the error and exits 1
reported: The report of rules, thresholds, speed and log is on stdout
fed_back: The result goes out: a block for Claude, a chart note as advice, a log line, or file output
claude_code -> received
writing_mode -> rules_ok? [report: no skip check]
received -> skip?
skip? -> quiet [yes], rules_ok? [no]
rules_ok? -> loaded [yes], failed_open [no, in a hook], failed [no, in a command]
loaded -> reported [report], checked [post, stop or file]
checked -> chart-suggest
checked -> fed_back [the scores]
```
