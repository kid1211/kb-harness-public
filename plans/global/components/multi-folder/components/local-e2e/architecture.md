```graph
begin asked
end reported
external project_start claude fixture e2e user
asked: the user or Claude runs the e2e script by hand.
asked.run: user
made: The fixture script made the three test folders fresh, with their own map.
made.run: fixture
user: the user or Claude, at a terminal
fixture: scripts/multi-folder-fixture.sh
e2e: tests/global/multi-folder-e2e/e2e.sh
reported.run: e2e
ran: The e2e started real claude sessions through project-start on the test folders.
ran.run: project_start
reported: The e2e printed one ok or not ok line per check.
project_start: scripts/project-start.sh, with the map of the test folders
claude: The claude CLI with -p, on a cheap model
asked -> made
made -> ran
ran -> reported
project_start -> claude
```
