// The map page of a KB folder: its whole tree, every level down. A folded node, such as
// miscellaneous, shows its count, and a click opens or closes it. Reset folds each one again.
// kb-types.py map copies this file into each kb-map.html, after a JSON block of the tree.

function under(tree, id, top) {
  for (let n = id; n !== null && n !== undefined; n = tree.nodes[n].parent) if (n === top) return true;
  return false;
}

function hidden(tree, id, open) {
  for (let p = tree.nodes[id].parent; p !== null && p !== undefined; p = tree.nodes[p].parent)
    if (tree.nodes[p].folded && !open.has(p)) return true;
  return false;
}

const at = (tree, open) => ({
  open,
  visible: new Set(Object.keys(tree.nodes).filter(id => under(tree, id, tree.home) && !hidden(tree, id, open))),
});
const start = tree => at(tree, new Set());
const click = (tree, st, id) => {
  if (!tree.nodes[id].folded) return st;
  const open = new Set(st.open);
  open.has(id) ? open.delete(id) : open.add(id);
  return at(tree, open);
};
const reset = tree => start(tree);

function render(doc, tree, st, go) {
  const box = doc.getElementById("map");
  box.textContent = "";
  const kids = {};
  for (const [id, n] of Object.entries(tree.nodes)) (kids[n.parent] = kids[n.parent] || []).push(id);
  const draw = (id, into) => {
    const n = tree.nodes[id], li = doc.createElement("li"), b = doc.createElement("button");
    b.textContent = n.name;
    b.className = "lv" + n.level + (kids[id] ? "" : " leaf") + (n.folded ? " fold" : "") + (n.area ? " " + n.area : "");
    b.title = id;
    b.onclick = () => go(click(tree, st, id));
    li.appendChild(b);
    const sub = (kids[id] || []).filter(k => st.visible.has(k));
    if (sub.length) {
      const ul = doc.createElement("ul");
      sub.sort().forEach(k => draw(k, ul));
      li.appendChild(ul);
    }
    into.appendChild(li);
  };
  const ul = doc.createElement("ul");
  draw(tree.home, ul);
  box.appendChild(ul);
  doc.getElementById("where").textContent = tree.home;
}

if (typeof module !== "undefined") module.exports = { start, click, reset };
if (typeof document !== "undefined") {
  const tree = JSON.parse(document.getElementById("tree").textContent);
  const go = st => render(document, tree, st, go);  // each click redraws from the new state
  document.getElementById("reset").onclick = () => go(reset(tree));
  const flip = document.getElementById("flip");  // vertical and horizontal, one class
  flip.onclick = () => {
    const wide = document.getElementById("map").classList.toggle("wide");
    flip.textContent = wide ? "Vertical" : "Horizontal";
  };
  go(start(tree));
}
