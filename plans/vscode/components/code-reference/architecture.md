```graph
begin idle
end copied
end kept
idle: No place is active. The status bar shows no hint.
idle.run: code-reference:code-reference.js
hinted: One of the four places is active. The status bar shows the one hint line.
hinted.run: code-reference:code-reference.js
pressed: The user pressed Cmd+Shift+C in the active place.
pressed.run: code-reference:code-reference.js
preview?: Is the place the Markdown preview?
waiting: The preview gives no channel. The page puts a mark in the clipboard. The extension reads it.
waiting.run: code-reference:code-reference.js
lines?: Does the place give selected lines?
copied: The clipboard holds the reference. The status bar says to switch to Claude and press Cmd+V.
copied.run: code-reference:code-reference.js
kept: Nothing is selected. The clipboard is as it was, and the hint comes back.
kept.run: code-reference:code-reference.js
idle -> hinted [a place becomes active]
hinted -> pressed [The user presses the key]
pressed -> preview?
preview? -> waiting [yes], lines? [no]
waiting -> lines?
lines? -> copied [yes], kept [no]
```
