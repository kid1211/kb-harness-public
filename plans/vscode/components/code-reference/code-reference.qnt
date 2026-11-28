// The code-reference part of vscode: one press of Cmd+Shift+C in one of four places. States are
// the state nodes of architecture.md. The decisions preview? and lines? sit inside the actions.
//
// Not modelled, held by the tests: the text of the reference, the hint and the note, the line
// ranges of the editor, the Markdown Diff and the preview, and the version name of a diff side.
module codeReference {
  pure val PLACES = Set("editor", "textDiff", "markdownDiff", "preview")

  var phase: str          // "idle", "hinted", "pressed", "waiting", "copied", "kept"
  var place: str          // the place the user is in
  var selected: bool      // the place has selected lines
  var clip: str           // the clipboard: "user" (the user's text), "mark" (the page's mark), "ref" (the reference)
  var restored: bool      // the extension put the user's clipboard text back after reading the mark

  /// R2: a press can start in any of the four places, with or without a selection.
  action initWith(p: str, s: bool): bool = all {
    phase' = "idle", place' = p, selected' = s, clip' = "user", restored' = false,
  }
  action init = {
    nondet p = PLACES.oneOf()
    nondet s = Set(true, false).oneOf()
    initWith(p, s)
  }

  /// R11: a place becomes active and the hint shows.
  action activate: bool = all {
    phase == "idle", phase' = "hinted",
    place' = place, selected' = selected, clip' = clip, restored' = restored,
  }

  /// R1: The user presses the key.
  action press: bool = all {
    phase == "hinted", phase' = "pressed",
    place' = place, selected' = selected, clip' = clip, restored' = restored,
  }

  /// R5: in the preview the page puts its mark in the clipboard.
  action askPreview: bool = all {
    phase == "pressed", place == "preview", phase' = "waiting", clip' = "mark",
    place' = place, selected' = selected, restored' = restored,
  }

  /// R1, R8: with lines the clipboard gets the reference. With none it stays as it was.
  action resolve: bool = all {
    phase == "pressed", place != "preview",
    phase' = if (selected) "copied" else "kept",
    clip' = if (selected) "ref" else clip,
    place' = place, selected' = selected, restored' = restored,
  }

  /// R5: the extension reads the mark and puts the user's text back, then copies or keeps.
  action readMark: bool = all {
    phase == "waiting",
    phase' = if (selected) "copied" else "kept",
    clip' = if (selected) "ref" else "user", restored' = true,
    place' = place, selected' = selected,
  }

  /// R1: a finished press stays where it ended.
  action done: bool = all {
    phase == "copied" or phase == "kept",
    phase' = phase, place' = place, selected' = selected, clip' = clip, restored' = restored,
  }

  action step = any { activate, press, askPreview, resolve, readMark, done }

  /// R8: with nothing selected the clipboard is the user's text.
  val noSelectionKept = phase == "kept" implies (clip == "user" and not(selected))
  /// R1: a copy leaves the reference in the clipboard.
  val copyIsRef = phase == "copied" implies (clip == "ref" and selected)
  /// R5: the page's mark never stays in the clipboard.
  val markNotLeft = (phase == "pressed" or phase == "copied" or phase == "kept") implies clip != "mark"
  /// R5: a press in the preview restores the user's clipboard before the result.
  val previewRestores = (phase == "copied" or phase == "kept") implies (place == "preview" implies restored)

  /// NEGATIVE CONTROL: false on purpose. A press can copy.
  val neverCopied = phase != "copied"

  /// copied
  /// R1, R2: a press in a text editor with lines copies the reference.
  run copyTest = initWith("editor", true)
    .then(activate).then(press).then(resolve)
    .expect(phase == "copied" and clip == "ref")

  /// kept
  /// R8: a press in the Markdown Diff with nothing selected keeps the clipboard.
  run keptTest = initWith("markdownDiff", false)
    .then(activate).then(press).then(resolve)
    .expect(phase == "kept" and clip == "user")

  /// R5: a press in the preview reads the mark and puts the user's text back before the copy.
  run previewTest = initWith("preview", true)
    .then(activate).then(press).then(askPreview).then(readMark)
    .expect(phase == "copied" and restored and clip == "ref")
}
