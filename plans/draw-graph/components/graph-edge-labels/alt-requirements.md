# Graph edge labels: requirements not kept

- 2026-11-21, record: R1, R2, R3, R4 and R5 written ✅ after the user said "all good" to the PoC of `dab7f269`. Evidence: the 7 tests of `check.test.js` pass, the full model check passes, and a sweep of 449 graph pages found 5 overlaps and crossings on `main` and on the branch. The ratio rule fails on 98 graphs, up from 23. the user saw that before his yes.
