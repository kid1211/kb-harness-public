```graph
begin reading
end closed
external uri_handler
skill preview_js
reading -> part_open [click a part], popup [click a link], card [hover a question]
card -> reading [pointer leaves], popup [click]
part_open -> reading [click the part again]
popup -> closed [Esc, click outside or close button], reason_input [click disagree], uri_handler [click agree or not checked]
reason_input -> uri_handler [send a reason], popup [cancel]
uri_handler -> popup [the toggle shows the value]
reading: The preview shows the page, with parts folded. Each question has its mark.
reading.run: preview_js
card: A small card shows the first sentence of the answer and the mark, at the side of the link.
card.run: preview_js
part_open: One part of a state is open.
part_open.run: preview_js
popup: The big popup of an answer page shows, with the toggle.
popup.run: preview_js, uri_handler
reason_input: The popup asks why the user disagrees.
reason_input.run: preview_js
preview_js: The library plan-preview, which rewrites the html of the preview
closed: The popup is gone and the page shows again.
uri_handler: The extension writes the feedback into the answer page.
```
