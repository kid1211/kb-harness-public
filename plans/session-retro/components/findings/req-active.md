# Findings: detailed requirements

## Requirements

- ✅ **R7. Find each block, by kind and subject:** [implement] The retro makes one finding for each kind and subject of block, with its count. A block is a hook that denied or asked on a tool call, a hook that sent Claude back after a call or at a stop, Claude Code's own guards, or a call the user rejected. A hook that failed, such as a script that is gone, is a block too.
  - Serves: F1
- ✅ **R6. Judge each block:** [implement] Each block finding says if the block was right and if Claude could have avoided it. A block is right when the call broke the rule that the hook or guard states. If the hook or guard states no rule, the verdict is `unknown`. Claude could have avoided it when a rule loaded in that session, in a `CLAUDE.md` or a skill, said so before the call.
  - Serves: F1
- ✅ **R2. Loops and duplicate work:** [implement] The retro makes a finding for each place where the session did the same work twice or went in a circle. Examples: the same call with the same input, a file read again with no change between, a step undone and done again. A retry after a short error that then works is not a loop. A test run again after a fix is not a loop.
  - Serves: F2
- ✅ **R3. Corrections by the user:** [implement] The retro makes a finding for each place where the user corrected how Claude read their words or what Claude did. A change of the user's own request is not one. A call the user rejected is a block, by R7, not a correction. The finding gives what the user said, how Claude read it, and why. Its tip says what the user needs to know, or how they can word it next time.
  - Serves: F3
- ✅ **R4. A fixed list of kinds:** [implement] Each finding has one kind from the fixed list in `references/findings-kinds.md` of the skill, so the reminder can count a kind across sessions. The list keeps the friction names of `/insights` where they fit, such as `misunderstood_request` and `wrong_approach`, and adds kinds for blocks and loops. Only a change through this plan adds a kind.
  - Serves: F1, F2, F3
- ✅ **R8. The model may drop a candidate:** [implement] A scan candidate is a finding only if the fork returns it. The fork drops a candidate that is not a real problem, and `check` adds back none that the fork left out. A finding that the fork adds itself, such as a circle, stays. *(Claude, 2026-11-02, recommended)*
  - Serves: F1, F2, F3
- ✅ **R9. A block is unseen by the scan, not by the fork:** [implement] `check` takes `unseen` from the scan candidate of the finding, by its `uuid` and kind, and ignores any `unseen` the fork writes. A block finding of an unseen candidate says `right: unknown`, whatever the fork wrote. A finding with no scan candidate is not unseen. *(Claude, 2026-11-02, recommended)*
  - Serves: F1
- ✅ **R10. One finding for each ID:** [implement] The list `check` returns holds each `id` once. When the fork returns two findings with one `id`, the first one stays. *(Claude, 2026-11-02, recommended)*
  - Serves: F1, F2, F3
