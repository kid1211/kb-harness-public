# Plan preview: design

## State transitions

The model is [plan-preview.qnt](plan-preview.qnt), module `planPreview`. The user flows of the old layout are in [alt-design-decisions.md](alt-design-decisions.md), for `p-design` to write the graph from.

```graph
import-graph: architecture.md
```

1. **Reading:** the page shows. Parts are folded, or two links per state show. See [Reading](#reading).
2. **Part open:** one part of a state is open. See [Part open](#part-open).
3. **Popup:** the big popup of an answer page shows, with the toggle. See [Popup](#popup).
4. **Reason input:** the popup asks why the user disagrees. See [Reason input](#reason-input).
5. **Closed:** the popup is gone and the page shows again. See [Closed](#closed).
6. **Card:** a small card shows the first sentence of an answer, at the side of its link (`hoverCard`, `leaveCard`). See [Card](#card).

The setting `planPreview.statesOnly` is a mode of Reading. It is a variable of the model, `statesOnly`, not a state.

## State deep dive

### Reading

The extension renders the page with markdown-it, then `PlanPreview.apply` rewrites the html. Under State deep dive each Guard, Invariants and Effect becomes a closed `<details>`. In the states-only view they leave the page, and two links take their place.

- **Guard:** the page is open in the preview, and no popup shows.
- **Invariants:** `noPartInStatesOnly`, `uiKnown`.
- **Expected output:** the page with folded parts, or with two links per state.
- **Effect:** every part folded, or in the states-only view only the links Effect and Invariants, each with its part in a tip shown on hover. Each research question has its mark as its bullet, ❓ open, or 🟢, 🔴, 🟠 or ⚪ from the feedback in its answer page, or ⚠️ deferred. Its hover legend puts the row of the mark on a white background, and a disagree's legend starts with the reason (R7).

### Part open

A click on a `<summary>` opens its `<details>`. The browser does this with no script.

- **Guard:** Reading, and the setting is off.
- **Invariants:** `noPartInStatesOnly`.
- **Effect:** the part shows. A second click returns to Reading.
- **Expected output:** the `<details>` of the part is open.

### Popup

A click on the link opens the popup, up to 80% of the window, scrolled to the heading of the question. The popup copies the hidden `pp-full` block, which holds the whole answer page and the toggle.

- **Guard:** Reading, on a link with a `pp-q` block.
- **Invariants:** `fileMatchesPreview`, `disagreeHasReason`, `uiKnown`.
- **Expected output:** the popup shows over the page.
- **Effect:** the popup shows. A click on agree or not checked (`pick`) is a `vscode://` link: the extension's URI handler runs `setFeedback`, and the page marks the value, and the mark of the question, at once. Esc, a click outside or the close button ends in Closed.

### Reason input

A click on disagree (`pickDisagree`) does not follow its link. The popup shows a box and two buttons.

- **Guard:** Popup, and the user clicked disagree.
- **Invariants:** `fileMatchesPreview`, `disagreeHasReason`, `uiKnown`.
- **Effect:** the text box opens with the last reason. Send is a real link: its `reason=` follows the text box, and the user clicks it, or presses Cmd+Enter then Enter. A script click would send the preview to a blank page. It marks disagree with the reason. Nothing is written before that. Cancel (`cancelReason`) returns to Popup and writes nothing. An empty reason sends nothing.

- **Expected output:** a text box and two buttons in the popup.

### Card

A hover on the text of a question under Research questions shows a small card (R416). It holds the first sentence of the answer in its staging page, and the mark of R7. It opens to the right of the link, or to the left near the right edge of the window. It is at most 40 characters wide and 4 lines high, so it covers no other question. The legend of R7 on the mark stays apart from it. It holds under `### the user` and `### Claude`.

- **Guard:** Reading or Closed, and the pointer is on the text of a question. Not on the mark.
- **Invariants:** `fileMatchesPreview`, `uiKnown`.
- **Effect:** the card shows and nothing is written (`hoverCard`). The pointer leaving returns to Reading (`leaveCard`). A click on the link opens the popup of R2 (`openPopup`).
- **Expected output:** a card of at most 40 characters by 4 lines beside the link, with the first sentence of the answer and the mark. `cardTest`.

### Closed

Esc, a click outside or the close button ends the popup (`closePopup`). The page shows again. A click on a part (`clickPart`) or on a link (`openPopup`) starts the next move.

- **Invariants:** `uiKnown`.
- **Expected output:** the page without a popup. `openAnswerTest`.

## Build checks

Plain JavaScript in `.claude/lib/plan-preview/`, tested in node: `node --test .claude/lib/plan-preview/tests/plan-preview.test.js`. One test per invariant and per effect. The model checks are `npx quint test` and `npx quint run --invariant=neverPopup`. `unchanged` is the step that changes nothing. `neverPopup` is the negative control, and the run must report a violation.

| Test (in `.claude/lib/plan-preview/tests/plan-preview.test.js`) | Holds |
|---|---|
| R1 Reading effect: Guard, Invariants and Effect fold, closed, inside the deep dive only | the Reading effect, folded |
| R1 Part open effect: a part with a nested list stays whole in its fold | the Part open effect |
| R4 noPartInStatesOnly: no part, no fold, no Guard text in the output | `noPartInStatesOnly` |
| R4 Reading effect: two links per state, each with its part in the tip | the Reading effect, states only |
| R416 Card effect: the card holds the first sentence and the mark, in at most 40 characters by 4 lines | `cardTest`, the Card effect |
| R416 Card effect: the side flips to the left near the right edge of the window | the Card effect, the side |
| R416 Card effect: a card on a question with no answer page, or no first sentence, shows the mark only | the Card effect, the edge |
| R7 marks: each research question's mark is its bullet, in place of the word, with its row marked on hover | the Reading effect, the marks |
| R7 marks: an open question is a question mark, a deferred one the warning sign; an open question keeps its number | the Reading effect, open and deferred |
| R2 Popup effect: the whole answer page is embedded hidden, and the question heading is marked | the Popup effect, the page |
| R3 Popup effect: a toggle of three vscode links, the current value marked | the Popup effect, the toggle |
| R3 Reason input effect: a disagree writes both lines of its question only | the Reason input effect |
| R3 history: each change adds a dated line, and the same value adds none | the Popup effect, the history line |
| R2 Closed effect: the popup closes and the page shows again | `openAnswerTest` |
| R3 reasonKept: agree and not_checked keep the reason, and a later disagree starts from it | `feedbackTest` |
| R3 disagreeHasReason: a disagree with no reason, or an unknown value, changes nothing | `disagreeHasReason` |
| R3 fileMatchesPreview: the link of each value, applied, gives the value the mark then shows | `fileMatchesPreview`, the mark the page then shows |
| R5: no emoji but the four marks, none in the stylesheet, and only palette colours | R5 |
| R6: the library loads in node, and the page side does nothing without a document | R6 |

Four more tests cover edges: a missing page or question, the end of a question section, a question with no feedback lines, and a reason with symbols in the link.

No check can see these, and they need a live VS Code: `uiKnown` (the card position at the real window edge, the 80% size, Esc, the outside click, the scroll to the question), the one confirm dialog of a `vscode://` link, and the refresh after a change of the setting. The page side is a thin layer over the tested html, and has no node test.

## Coverage

| Requirement | Held by |
|---|---|
| R1 | `noPartInStatesOnly`, `clickPart`, `foldTest` |
| R2 | `openPopup`, `closePopup`, `openAnswerTest`, the Popup tests |
| R3 | `fileMatchesPreview`, `disagreeHasReason`, `sendReason`, `feedbackTest` |
| R4 | `noPartInStatesOnly`, `setStatesOnly`, `statesOnlyTest` |
| R5 | the R5 test: no emoji, palette variables only |
| R7 | the two R7 marks tests |
| R416 | `hoverCard`, `leaveCard`, `cardTest`, `fileMatchesPreview` (a hover writes nothing), and the three Card tests. The 40 by 4 size and the side are not in the model, the tests hold them |
| card | `cardTest` |
| closed | `openAnswerTest` |
| R6 | the R6 test: `module.exports`, run by `node --test` |
| F1 | `foldTest` |
| F2 | `openAnswerTest` |
| F3 | `feedbackTest` |
| F4 | `statesOnlyTest` |

## Risks

- The model keeps the reason as it is on a move to agree. Quint has no string join, so the `===` lines and the dated change are checked by the unit tests, not by the model.

- **The confirm dialog.** The first feedback click asks "Allow the extension to open this URI?". Open question 1 accepts it. A tick on "Do not ask me again" ends it.
- **A stale answer page.** The render step reads the answer page when the index page renders. An edit of the answer page shows after the index renders again. The page marks the new value at once, so the user sees their own click.
- **A crafted link writes to a file.** The handler writes only a `.md` file, only inside a `## Q<n>.` section, and only the two feedback lines. A bad value changes nothing.
- **The preview may swallow a `vscode://` click.** The research read the source and did not try it live. If it fails, the toggle shows the value and writes nothing. This is not tested.
- **The refresh command.** `markdown.preview.refresh` after a change of the setting was not checked in a live window.
- **Large answer pages.** Each question embeds the whole page, so four questions of one page embed it four times. Fine for pages of this size.

## Appendix

- [Research: what the preview lets an extension do](../../../../../personal/claude-research/staging/2026-10-24-p-spec-flow/preview-mechanics.staging.md): the `vscode://` link, the render-time read, the click, the setting.
- Run again: `npx quint test plans/vscode/components/plan-preview/plan-preview.qnt --main=planPreview`.
