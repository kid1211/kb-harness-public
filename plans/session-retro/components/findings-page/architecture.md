```graph
begin none
end full
skill findings_page_py
none: No page yet for this session.
none.run: findings_page_py
cold: A one-line page. The last transcript entry is over an hour old, so it was not read
cold.run: findings_page_py
full: The page with each finding and its status. A run again keeps each status
full.run: findings_page_py
findings_page_py: findings-page.py, which writes the page, checks it for secrets and moves it
none -> cold [last entry over an hour old], full [transcript read]
cold -> full [a run again reads the transcript]
```
