# Findings page: designs not chosen

- **The model writes the page itself.** Not chosen: a model that runs no tool cannot leak a write elsewhere, and a script can merge statuses the same way each time. The model returns JSON, and `findings-page.py` writes the page.
- **A cold run writes over a full page.** Not chosen: R7 says a cold page never takes the place of a full page. A late run would lose the findings.
- **The script masks a secret and commits.** Not chosen: a mask can miss part of a value. R2 says the commit script refuses the page. The user sees the refusal in the reminder.
- **Statuses in a separate JSON file.** Not chosen: The user edits the page, so the status sits on the page, next to the finding.
- **Write the page in `personal`, then check it.** Replaced after the fresh check of the first design: a refused page stayed in the working tree of `personal`, and any later commit of the folder would push the secret. The page is now written outside the KB and moves in only when clean.
- **The date of the run in the page name.** Replaced after the fresh check: a run again on a later day made a second page. The page is found by the session ID, and a new page takes the date of the first transcript entry.
- **The model gives each finding its ID.** Replaced after the fresh check: a run again could list the findings in another order, and a status would move to another finding. `findings.py check` makes the ID from the kind and the subject or `uuid`.
