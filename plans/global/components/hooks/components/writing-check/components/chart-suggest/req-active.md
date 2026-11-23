# Chart suggest: detailed requirements

## Requirements

- 🚀 **R1. One catalog of chart forms:** [implement] one page lists each chart form that `dataviz` names, one row per form. Each row has four columns: what the form is, what it can do, when to use it, and a help score from 1 to 5: how much the form helps a reader understand the data. A form named only by another Anthropic tool, such as the Claude Docs guide, gets a row too, with its source. Claude writes the four columns by hand, and the user confirms them.
  - Serves: F1
- 🚀 **R2. A score with a rule:** [implement] the page states the rule behind each score, so two readers give the same score. The rule follows the evidence: a tested result and an accurate cue, such as position or length, score high. Practice only, or a weak cue, such as area or angle, score lower.
  - Serves: F1
- 🚀 **R3. How to read dataviz:** [implement] the page teaches how to find what `dataviz` offers. It names where the skill sits, which of its files list the forms, and the Claude Code version it read.
  - Serves: F1
- 🚀 **R4. A script finds new forms:** [implement] a script reads the form lists of `dataviz` and prints each form it names that the catalog lacks, and each catalog row that `dataviz` does not name. If it cannot find `dataviz`, it fails and says so. Claude runs it after a Claude Code update, or when the user asks.
  - Serves: F2
- 🚀 **R5. A docs check suggests a chart:** [implement] after each markdown edit that `writing-check` R2 checks, with the docs mode of R9 not `off`, the check reads what the edit adds. If it matches a row of the signal table of R7, the check names that row's form, and why.
  - It is not a scored rule of `writing-check` R4. It sends Claude a note, not a failure: Claude decides, and the edit is not sent back to fix.
  - It keeps to R7, R8 and R10 of `writing-check`: it logs, it is quick, and it skips the same files.
  - If the catalog page is missing, the check suggests nothing and says so once in the log.
  - Replies are not checked.
  - Serves: F3
- 🚀 **R6. The best way to detect the need:** [research] which way says best whether a doc's content needs a chart, and which one: words in the text, signals in a table, or a local library? The check keeps to `writing-check` R8, with no LLM. An LLM judgment can only be a rule that Claude follows while it writes. The best way catches the most content that a chart helps, with the fewest wrong notes, in under a second. The answer names the signals of R7, with evidence.
  - Serves: F3
- 🚀 **R7. One signal table:** [implement] the catalog page holds a signal table. Each row has a signal kind (words or a table shape), the test that finds it, the form it suggests, and why. The check of R5 reads this table, so a change to the page changes the check.
  - Serves: F3
- 🚀 **R9. Any table-like data:** [implement] the check of R5 reads table-like data in other shapes too, with the same signals of R7. That covers a `csv` or `tsv` code block in the doc, and a link from the doc to a `.csv`, `.tsv` or `.xlsx` file. If a linked file is missing, too large, or in iCloud only, the check skips it and does not download it. If the doc only names data, such as "the CSV" or "the sheet", the check notes that a chart may help, with no form, since it cannot see the data.
  - Serves: F3
