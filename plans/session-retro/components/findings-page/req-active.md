# Findings page: detailed requirements

## Requirements

- ✅ **R7. One page per session:** [implement] The retro writes one staging page per session in `claude-research/session-retro/` of the `personal` KB, in the layout of the `kb` skill. A script writes it, and `kb-check.py` checks it before the commit. Its name is `<date of the session's first entry>-<first 8 characters of the session ID>.staging.md`. Each finding links to the session ID and the `uuid` of its transcript line. A session with no findings gets a page that says so.
  - If the retro runs again on the same session, on any date, it updates the same page. It keeps the status of each finding, and it never puts a one-line cold page in place of a full page.
  - Serves: F1
- ✅ **R2. No secrets on the page:** [implement] The page holds no password, token, API key or account number from the transcript. If a finding needs such a value to make sense, the page names what it is and leaves the value out. The commit script refuses a page that matches a secret pattern.
  - Serves: F2
- ✅ **R5. Each finding has a status:** [implement] Each finding on the page is `open`, `confirmed` or `dropped`. The retro writes it `open`. Only the user changes it.
  - Serves: F3
- ✅ **R6. Only a confirmed finding moves:** [implement] A finding moves out of staging, into a consolidated page or a harness change, only after the user confirms it. This build makes no move. It only lists the confirmed findings for the user.
  - Serves: F3
