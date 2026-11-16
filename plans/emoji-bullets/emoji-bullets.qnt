// emoji-bullets: apply() turns the emoji that starts a list item into its bullet, and adds the status
// legend on hover to a requirement item and a Requirements heading. States are the state nodes of
// architecture.md. The decisions item? and legend? sit inside the actions that leave start and bulleted.
//
// One item stands for all items: apply() works on each item alone. Not modelled, held by the tests:
// the regular expression, the item with an inline style, the HTML of the legend, the CSS.
module emojiBullets {
  var phase: str      // "start", "bulleted", "legend", "rendered"
  var leadEmoji: bool // the item text starts with an emoji
  var isReq: bool     // the item is "<status emoji> **R<n>…" with one of the four status emojis
  var isHeading: bool // the node is a "Requirements" heading
  var bullet: bool    // the emoji is the bullet, once
  var legend: bool    // the hover legend is there
  var rowOn: bool     // one row of the legend stands out

  /// R1, R2: the input as the page gives it. A heading has no emoji and no row.
  action initWith(e: bool, r: bool, h: bool): bool = all {
    phase' = "start", leadEmoji' = (e and not(h)), isReq' = (e and r and not(h)), isHeading' = h,
    bullet' = false, legend' = false, rowOn' = false,
  }
  action init = {
    nondet e = Set(true, false).oneOf()
    nondet r = Set(true, false).oneOf()
    nondet h = Set(true, false).oneOf()
    initWith(e, r, h)
  }

  /// R1: an item that starts with an emoji shows it as the bullet.
  action markBullet: bool = all {
    phase == "start", leadEmoji,
    phase' = "bulleted", bullet' = true,
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, legend' = legend, rowOn' = rowOn,
  }

  /// R2, R5: a requirement item or a Requirements heading gets the legend. Only an item has its own row marked.
  action addLegend: bool = all {
    phase == "bulleted", isReq or isHeading,
    phase' = "legend", legend' = true, rowOn' = isReq,
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, bullet' = bullet,
  }

  /// R2: a heading has no emoji, so it goes from start to its legend with no row.
  action headingLegend: bool = all {
    phase == "start", not(leadEmoji), isHeading,
    phase' = "legend", legend' = true, rowOn' = false,
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, bullet' = bullet,
  }

  /// R1: any other item, with no emoji and no heading, is returned as it is.
  action skipAll: bool = all {
    phase == "start", not(leadEmoji), not(isHeading),
    phase' = "rendered",
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, bullet' = bullet, legend' = legend, rowOn' = rowOn,
  }

  /// R1: a bulleted item that is no requirement item is returned with its bullet only.
  action finishBulleted: bool = all {
    phase == "bulleted", not(isReq or isHeading),
    phase' = "rendered",
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, bullet' = bullet, legend' = legend, rowOn' = rowOn,
  }

  /// R2, R5: the page is returned with its legend.
  action finish: bool = all {
    phase == "legend",
    phase' = "rendered",
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, bullet' = bullet, legend' = legend, rowOn' = rowOn,
  }
  /// R1: a finished run stays where it ended.
  action done: bool = all {
    phase == "rendered", phase' = phase,
    leadEmoji' = leadEmoji, isReq' = isReq, isHeading' = isHeading, bullet' = bullet, legend' = legend, rowOn' = rowOn,
  }
  action step = any { markBullet, addLegend, headingLegend, skipAll, finishBulleted, finish, done }

  /// R1: the emoji is the bullet exactly when the text starts with one.
  val bulletIffEmoji = phase == "start" or bullet == leadEmoji
  /// R2: the legend is on a requirement item and on a heading, and on nothing else.
  val legendOnlyWhereAsked = phase != "rendered" or legend == (isReq or isHeading)
  /// R5: only a requirement item has a row marked, and a heading never has.
  val rowOnlyOnItem = (not(rowOn) or isReq) and not(isHeading and rowOn)
  /// R5: a requirement item that shows its legend has its row marked.
  val itemRowMarked = phase != "rendered" or not(isReq) or rowOn
  /// NEGATIVE CONTROL: false on purpose. A rendered page can have no bullet.
  val noBulletEver = phase != "rendered" or not(bullet)

  /// R1, R2, R5: an item with a status emoji gets bullet, legend and row.
  run itemTest = {
    initWith(true, true, false).then(markBullet).then(addLegend).then(finish)
      .then(all { assert(bullet and legend and rowOn and phase == "rendered"), done })
  }
  /// R2, R5: a heading gets the legend and no row.
  run headingTest = {
    initWith(false, false, true).then(headingLegend).then(finish)
      .then(all { assert(not(bullet) and legend and not(rowOn)), done })
  }
  /// R1: a plain item is left alone.
  run plainTest = {
    initWith(false, false, false).then(skipAll)
      .then(all { assert(not(bullet) and not(legend) and not(rowOn)), done })
  }
  /// R1: an item with an emoji that is no requirement item has its bullet and no legend.
  run bulletOnlyTest = {
    initWith(true, false, false).then(markBullet).then(finishBulleted)
      .then(all { assert(bullet and not(legend)), done })
  }
  /// R1, R2, R5: the item with a status emoji reaches the end node.
  /// rendered
  run renderedTest = {
    initWith(true, true, false).then(markBullet).then(addLegend).then(finish)
      .then(all { assert(phase == "rendered" and bullet and legend and rowOn), done })
  }
}
