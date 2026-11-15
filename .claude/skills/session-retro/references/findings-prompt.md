The session has ended. Look back at it and judge the candidates below.

- Use no tool.
- Reply with one JSON list and nothing else.

## What to return

One object per finding, with these fields:

- `kind`: one kind from the list below.
- `uuid`: the `uuid` of the candidate. For a `circle` you find yourself, use the `uuid` of the nearest candidate or user turn in the list.
- `subject`: for a candidate, copy its subject. For a finding you add, a short name.
- `event`: what happened, in one sentence.
- `cause`: why it happened, in one sentence.
- For `misunderstood_request` or `wrong_approach`: `event` quotes what the user said and says how you read it. `cause` says why you read it that way.
- `change`: what to change in the harness so it does not happen again, such as a rule in a `CLAUDE.md`, a skill step, or a hook. Write `None.` if nothing should change.
- `tip`: what the user can know or say next time. Write `None.` if there is no tip.
- For a block only: `right` and `avoidable`.
  - `right` is `yes` when the call broke the rule the hook or guard states, `no` when it did not, and `unknown` when the hook or guard states no rule.
  - `avoidable` is `yes` when a rule loaded in this session, in a `CLAUDE.md` or a skill, said so before the call. Else `no`.
  - If a candidate is `unseen`, it was before the last compaction and you cannot see it. Give `right: unknown`.

## Rules

- Drop a candidate that is not a real problem, such as a retry that then worked.
- A user turn is a finding only if the user corrected how you read their words or what you did. A new request is not a correction.
- Name no password, token, key or account number. If a finding needs one, say what it is and leave the value out.
- Write short, plain sentences.

## Kinds

{kinds}

## Candidates

{candidates}
