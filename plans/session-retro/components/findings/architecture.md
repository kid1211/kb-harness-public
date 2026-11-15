```graph
begin scan
end findings_json
scan: findings.py reads the transcript and lists each candidate: a block, a loop or a turn of the user
scan.run: findings:findings.py
judge: The fork keeps the real candidates, drops the rest, and gives each a cause, verdict, change and tip
judge.run: findings:findings-prompt.md
findings_json: One JSON list of findings, with a listed kind and each ID once
scan -> judge
judge -> findings_json
```
