# Plan preview: designs not chosen

## Hover alone opens the popup

Rejected. A popup of 80% of the window moves the pointer off the link, so it closes at once. A hover shows a small card, and a click opens the popup. The card is the state `card` (R416, 2026-11-02).

## The preview script fetches the answer page

Rejected. The preview's content security policy has no `connect-src`, so `fetch` is blocked. The render step reads the page in node and embeds it hidden.

## A `command:` link writes the feedback

Rejected. The preview does not enable command links. A `vscode://` link reaches the URI handler of the extension.

## A script folds the parts

Rejected. A native `<details>` folds with no script, and survives a re-render of the preview.

## One model state per setting value

Rejected. The setting is a mode of Reading, so it is a variable (`statesOnly`), not a state.

## User flows of the old layout

Moved here from `user-flow.md` on 2026-10-25, at the merge of main: the layout has one graph per level, `architecture.md`. `p-design` writes the graph from them.

### Plan preview: user flows

Four flows. Each is the ideal path the user wants.

#### F1. Read a design with folded parts

Uses R1, R5.

```graph
begin open_design
end read
open_design: The user opens a 1-design.md in the preview
open_design -> see_states
see_states: Each state shows with its parts folded
see_states -> want_more?
want_more?: Does the user want a part?
want_more? -> open_part [yes], read [no]
open_part: A click opens Guard, Invariants or Effect
open_part -> fold_part
fold_part: A second click folds it
fold_part -> read
```

#### F2. Open a research answer

Uses R2, R5, R7.

```graph
begin see_link
end back
see_link: The user sees a research question under Research questions, with its mark
see_link -> enough?
enough?: Does the mark tell enough? A hover on it says what it means
enough? -> back [yes], click [no]
click: A click opens the answer page in a popup, at the question
click -> read
read: The user scrolls and reads
read -> back [Esc, click outside or close button]
```

#### F3. Mark an answer agree or disagree

Uses R2, R3, R5.

```graph
begin popup
end saved
popup: The answer popup is open
popup -> verdict?
verdict?: What does the user think?
verdict? -> pick_agree [agree], ask_reason [disagree], saved [not checked]
pick_agree: A click on agree
pick_agree -> saved
ask_reason: The popup asks for a reason
ask_reason -> send_reason
send_reason: The user types why and sends it
send_reason -> saved
saved: The answer page holds the value, and the last disagree reason
```

#### F4. See only the states

Uses R4, R5.

```graph
begin set
end read
set: The user turns on the setting planPreview.statesOnly
set -> see_links
see_links: Each state shows its text and two links, Effect and Invariants
see_links -> hover
hover: A hover on a link shows that part
hover -> read
```

## A hover card that holds the whole answer

Rejected (R416). A big card covered the next link, and the user could not click it. The card holds one sentence, at most 40 characters by 4 lines, to the side of the link.
