```graph
begin retro
end recorded
external retro
retro: retro.sh of session-retro, after worktree-end
spec-rounds: components/spec-rounds/ One row per spec round, and the Spec section of the page
spec-levels: components/spec-levels/ The SCD type 2 table of the plan levels
spec-backfill: components/spec-backfill/ A first run that fills both tables and the old pages
recorded: Both files and the page hold the numbers of the session
retro -> spec-rounds
spec-rounds -> spec-levels
spec-levels -> recorded
spec-backfill -> spec-rounds [once]
spec-backfill -> spec-levels [once]
```
