# Findings: dropped requirements and closed questions

## R1. Hook blocks

**Requirement:** The retro makes a finding for each block: a hook that denied or asked on a tool call, a hook that sent Claude back, Claude Code's own guards, and a call the user rejected. A hook that failed is a finding too. Each finding also says whether the block was right, and whether Claude could have avoided it.

**Why it is not chosen:**

- A fresh check found two ideas in it: finding the blocks, and judging them.
- R5 finds them. R6 judges them, and says what "avoidable" means. Dropped 2026-10-24.

## R5. Find each block

**Requirement:** The retro makes a finding for each block: a hook that denied or asked on a tool call, a hook that sent Claude back after a call or at a stop, Claude Code's own guards, and a call the user rejected. A hook that failed, such as a script that is gone, is a finding too.

**Why it is not chosen:** a fresh check of the design found that one session had 363 guard blocks. One finding for each would bury the rest. R7 makes one finding per kind and subject, with its count. Dropped 2026-10-24.
