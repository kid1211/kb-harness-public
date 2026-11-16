// markdown-diff: render(old, new) gives the new text as rendered Markdown with its changes marked.
// States are the state nodes of architecture.md.
//
// One block stands for all: render() decides on each block alone, once jsdiff has paired the blocks.
// Not modelled, held by the tests: front matter as a table, the word diff, the data-src-lines,
// fold(), and the drawing of graph blocks by the caller.
module markdownDiff {
  var phase: str      // "start", "frontmatter", "split", "compare", "marked", "rendered"
  var inOld: bool     // the block is in the old text
  var inNew: bool     // the block is in the new text
  var same: bool      // both texts hold it unchanged
  var alike: bool     // old and new are of one type and share more than 40% of their text
  var isCode: bool    // a code block, a graph block too
  var mark: str       // "", "none", "ins", "del", "chg", "delins"

  /// R1: any block, in any combination of sides. A block in both sides that is the same is unchanged.
  action initWith(o: bool, n: bool, s: bool, a: bool, c: bool): bool = all {
    phase' = "start", inOld' = o, inNew' = n, same' = (o and n and s), alike' = (o and n and a), isCode' = c, mark' = "",
  }
  action init = {
    nondet o = Set(true, false).oneOf()
    nondet n = Set(true, false).oneOf()
    nondet s = Set(true, false).oneOf()
    nondet a = Set(true, false).oneOf()
    nondet c = Set(true, false).oneOf()
    all { o or n, initWith(o, n, s, a, c) }
  }

  /// R1: front matter becomes a table.
  action toFrontmatter: bool = all {
    phase == "start", phase' = "frontmatter",
    inOld' = inOld, inNew' = inNew, same' = same, alike' = alike, isCode' = isCode, mark' = mark,
  }
  /// R1: the texts become blocks.
  action toSplit: bool = all {
    phase == "frontmatter", phase' = "split",
    inOld' = inOld, inNew' = inNew, same' = same, alike' = alike, isCode' = isCode, mark' = mark,
  }
  /// R1: jsdiff pairs the blocks.
  action toCompare: bool = all {
    phase == "split", phase' = "compare",
    inOld' = inOld, inNew' = inNew, same' = same, alike' = alike, isCode' = isCode, mark' = mark,
  }

  /// R1: a block gets its mark. Same: none. Only new: added. Only old: removed.
  /// Both and changed: words marked in one block, if alike and no code. Else removed and added whole.
  action markBlock: bool = all {
    phase == "compare", phase' = "marked",
    mark' =
      if (same) "none"
      else if (inNew and not(inOld)) "ins"
      else if (inOld and not(inNew)) "del"
      else if (alike and not(isCode)) "chg"
      else "delins",
    inOld' = inOld, inNew' = inNew, same' = same, alike' = alike, isCode' = isCode,
  }

  /// R1: the page is returned.
  action finish: bool = all {
    phase == "marked", phase' = "rendered",
    inOld' = inOld, inNew' = inNew, same' = same, alike' = alike, isCode' = isCode, mark' = mark,
  }
  /// R1: a finished run stays where it ended.
  action done: bool = all {
    phase == "rendered", phase' = "rendered",
    inOld' = inOld, inNew' = inNew, same' = same, alike' = alike, isCode' = isCode, mark' = mark,
  }
  action step = any { toFrontmatter, toSplit, toCompare, markBlock, finish, done }

  /// R1: a block in the new text only is added, whole.
  val addedWhole = phase != "marked" or not(inNew and not(inOld)) or mark == "ins"
  /// R1: a block in the old text only is removed, whole.
  val removedWhole = phase != "marked" or not(inOld and not(inNew)) or mark == "del"
  /// R1: an unchanged block has no mark.
  val sameNoMark = phase != "marked" or not(same) or mark == "none"
  /// R1: a code block, a graph too, never has words marked: old shows removed, new shows added.
  val codeNeverMerges = phase != "marked" or not(isCode and inOld and inNew and not(same)) or mark == "delins"
  /// R1: words are marked only in a block that is in both texts, changed, alike.
  val chgOnlyAlike = phase != "marked" or mark != "chg" or (inOld and inNew and alike and not(same) and not(isCode))
  /// NEGATIVE CONTROL: false on purpose. A block in both texts is sometimes changed.
  val neverChanged = phase != "marked" or mark != "chg"

  /// R1: a block in both texts, changed and alike, gets its words marked.
  run changedTest = {
    initWith(true, true, false, true, false).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock)
      .then(all { assert(mark == "chg"), finish }).then(done)
  }
  /// R1: a block only in the new text is added.
  run addedTest = {
    initWith(false, true, false, false, false).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock)
      .then(all { assert(mark == "ins"), finish }).then(done)
  }
  /// R1: a block only in the old text is removed.
  run removedTest = {
    initWith(true, false, false, false, false).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock)
      .then(all { assert(mark == "del"), finish }).then(done)
  }
  /// R1: a changed code block is removed and added, not merged.
  run codeTest = {
    initWith(true, true, false, true, true).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock)
      .then(all { assert(mark == "delins"), finish }).then(done)
  }
  /// R1: an unchanged block has no mark. A rewritten paragraph is removed and added.
  run sameTest = {
    initWith(true, true, true, true, false).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock)
      .then(all { assert(mark == "none"), finish })
      .then(initWith(true, true, false, false, false)).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock)
      .then(all { assert(mark == "delins"), finish }).then(done)
  }
  /// R1: the page reaches the end node.
  /// rendered
  run renderedTest = {
    initWith(true, true, false, true, false).then(toFrontmatter).then(toSplit).then(toCompare).then(markBlock).then(finish)
      .then(all { assert(phase == "rendered"), done })
  }
}
