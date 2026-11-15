# Findings: designs not chosen

## No model

- The first version had no model, as it said the part has no states.
- Replaced 2026-11-02: the architecture shows three state nodes, so `findings.qnt` now models them.
- It holds the rules that `check` applies to the fork's result.

## The model adds every candidate back

- The first model put every scan candidate into the list after the fork, and read `unseen` from the fork's record.
- Replaced 2026-11-02: R8 lets the fork drop a candidate, R9 takes `unseen` from the scan, and R10 keeps one finding for each ID. The negative control now fails because `check` drops a bad kind, not because of the phase.
