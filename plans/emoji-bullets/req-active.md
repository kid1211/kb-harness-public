# Emoji bullets: detailed requirements

## Requirements

- ✅ **R1. Emoji as the bullet:** a list item whose text starts with an emoji shows that emoji in place of the bullet dot, at the same indent, and once only. An emoji later in the text stays as text. *(the user, 2026-10-20)*
  - Serves: F1
- ✅ **R2. Legend on hover:** a hover on a requirement item, `- <status emoji> **R<n>…`, or on a "Requirements" heading shows the four statuses of `p-z-helper-file-structure` R107, one per line, each with its emoji, in a tooltip 30% bigger than the text. *(the user, 2026-10-20)*
  - Serves: F2
- ✅ **R5. The item's own row stands out:** on a requirement item, the legend shows the row of that item's status on a white background, the whole row, with dark text. On the heading, no row is marked. *(the user, 2026-10-24)*
  - Serves: F2
- ✅ **R3. Where:** the VS Code Markdown preview and its Markdown Diff. Not the plan viewer. *(the user, 2026-10-20)*
  - Serves: F1, F2
- ✅ **R4. Easy to remove:** all of it is in `.claude/lib/emoji-bullets/`. Each place that uses it has one `apply()` call. Removing it is the folder, those calls, its stylesheet in `package.json` and `extension.js`, and one line of `build.sh`. *(the user, 2026-10-20)*
  - Serves: F3
