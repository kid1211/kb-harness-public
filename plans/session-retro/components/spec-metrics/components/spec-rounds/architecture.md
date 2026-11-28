```graph
begin start
end recorded skipped
fail failed
skill spec_rounds_py
start: retro.sh has moved the page into the KB, and calls spec-rounds.py record
start.run: spec_rounds_py
scanned: The rounds of the session are found from its automatic plan commits
scanned.run: spec_rounds_py
any?: Did the session run a round?
skipped: No rows and no Spec section. The page commits as it is
written: Its rows replace its old rows in spec-rounds.csv, and the Spec section replaces the old one
written.run: spec_rounds_py
recorded: commit-page.sh commits the page and spec-rounds.csv together
failed: The error goes to failures.log. The page still commits
spec_rounds_py: spec-rounds.py, which reads the transcript and writes the rows and the section
start -> scanned [transcript read], failed [no transcript]
scanned -> any? [rounds counted]
any? -> written [yes], skipped [no]
written -> recorded
scanned -> failed [write error]
```
