import { el, relativeLabel, svgIcon, thumbnailUrl, ICONS } from "./shared.js";

/**
 * One result row in the Spotlight list: thumbnail + name (or an inline
 * rename field) + relative time. `callbacks` is `{ onSelect, onOpen,
 * onCommitRename, onCancelRename, onContextMenu }`, all called with no
 * extra bookkeeping — the caller owns `render()`. `isCopied` briefly
 * overlays a check badge on the thumbnail right after this row was copied.
 */
export function renderRow(shot, isSelected, isRenaming, isCopied, callbacks) {
  const row = el("div", isSelected ? "row selected" : "row");
  row.addEventListener("click", () => callbacks.onSelect(shot));
  row.addEventListener("dblclick", () => {
    callbacks.onSelect(shot);
    callbacks.onOpen();
  });
  row.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    callbacks.onSelect(shot);
    callbacks.onContextMenu(shot, e.clientX, e.clientY);
  });

  const thumb = el("div", "thumb");
  thumbnailUrl(shot.path, 56).then((url) => {
    if (url) thumb.appendChild(el("img")).src = url;
  });
  if (isCopied) {
    const badge = el("div", "copied-badge");
    badge.innerHTML = svgIcon(ICONS.check);
    thumb.appendChild(badge);
  }
  row.appendChild(thumb);

  const meta = el("div", "meta");
  if (isRenaming) {
    const nameBox = el("div", "name");
    const input = document.createElement("input");
    input.value = shot.name;
    input.spellcheck = false;
    nameBox.appendChild(input);
    meta.appendChild(nameBox);
    setTimeout(() => {
      input.focus();
      input.select();
    });
    input.addEventListener("keydown", (e) => {
      e.stopPropagation();
      if (e.key === "Enter") callbacks.onCommitRename(shot, input.value);
      if (e.key === "Escape") callbacks.onCancelRename();
    });
  } else {
    meta.appendChild(el("div", "name", shot.name));
  }
  meta.appendChild(el("div", "when", relativeLabel(shot.created_at)));
  row.appendChild(meta);
  return row;
}
