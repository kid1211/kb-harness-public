/* emoji-bullets: in rendered Markdown, a list item whose text starts with an emoji shows the
 * emoji in place of its bullet dot, at the same indent, and once only. A requirement item
 * ("- 🎯 **R1. …**") and a "Requirements" heading get the status legend on hover, drawn by
 * emoji-bullets.css. On an item, the row of its own status stands out.
 *   legend(rows, on, first)                  // the legend html: rows of [emoji, text], `on` marked, `first` a line above
 *   html = EmojiBullets.apply(html)          // a page, after the Markdown is rendered
 *   const { apply } = require("./emoji-bullets.js")   // node, such as a markdown-it renderer
 * To remove it: drop this folder, the one apply() call and the stylesheet in each place that uses it.
 */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.EmojiBullets = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const STATUS = [
    ["🎯", "todo: written, nothing more yet"],
    ["🌟", "researched: its research is answered"],
    ["🚀", "designed: the design covers it"],
    ["✅", "built: a passing check shows it"],
  ];
  const LEGEND = STATUS.map(([e, t]) => `${e} ${t}`).join("&#10;");
  const isStatus = e => STATUS.some(([s]) => s === e);
  // A real element, not a CSS ::after, so one row can stand out. aria-hidden: it repeats what the marks say.
  const legend = (rows, on, first = "") => `<span class="eb-legend" aria-hidden="true">` +
    (first ? `<span class="eb-first">${first}</span>` : "") +
    rows.map(([e, t]) => `<span class="eb-row${e === on ? " eb-on" : ""}">${e} ${t}</span>`).join("") + "</span>";

  function apply(html) {
    return html
      .replace(/<li(\s[^>]*)?>(\s*(?:<p[^>]*>)?\s*)(\p{Extended_Pictographic}️?)\s*(?=(<strong>R\d+)?)/gu,
        (m, attrs = "", lead, emoji, req) => /\sstyle=/.test(attrs) ? m :
          `<li${attrs} style="list-style-type: '${emoji} '"${req && isStatus(emoji) ? ` data-legend="${LEGEND}"` : ""}>${req && isStatus(emoji) ? legend(STATUS, emoji) : ""}${lead}`)
      .replace(/<(h[1-6])(\s[^>]*)?>(\s*Requirements\s*)<\/\1>/g,
        (m, h, attrs = "", text) => /\sdata-legend=/.test(attrs) ? m : `<${h}${attrs} data-legend="${LEGEND}">${text}${legend(STATUS)}</${h}>`);
  }

  return { apply, STATUS, legend };
});
