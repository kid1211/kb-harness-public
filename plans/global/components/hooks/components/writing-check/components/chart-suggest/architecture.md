```graph
begin edit
end done
external writing_check
external catalog_script
edit.run: chart-suggest:.claude/hooks/writing-check.py
read_signals.run: chart-suggest:.claude/hooks/writing-check.py
scan.run: chart-suggest:.claude/hooks/writing-check.py
note.run: chart-suggest:.claude/hooks/writing-check.py
missing.run: chart-suggest:.claude/hooks/writing-check.py
writing_check: The writing-check hook. It calls the chart rule after a markdown edit.
catalog_script: scripts/chart-catalog.py. It lists the forms dataviz names that the catalog lacks.
edit: A markdown edit passes the checks of writing-check
mode?: Is the docs mode off, or is the file the catalog page itself?
catalog?: Does the catalog page exist, with a signal table?
missing: Log once that the catalog page is missing. Suggest nothing
read_signals: Read the signal table of the catalog page: signal, test, form, why
scan: Read the added text, its tables, its csv blocks and the files it links to. Skip code
found?: Does a row of the signal table match?
note: Send Claude one line per match: the form and why. Advice, never a failure
done: The edit goes on. A clean edit gets no chart note
writing_check -> edit
catalog_script -> read_signals [reads the same page]
edit -> mode?
mode? -> done [yes], catalog? [no]
catalog? -> read_signals [yes], missing [no]
missing -> done
read_signals -> scan
scan -> found?
found? -> note [yes], done [no]
note -> done
```
