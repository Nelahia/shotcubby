import { invoke, el, svgIcon, ICONS, timeLabel, sourceLabel, thumbnailUrl } from "./shared.js";

/**
 * One thumbnail tile in the popover grid: image + hover actions + inline
 * rename + metadata row. `renaming` is `{ id, setId }` so the caller (which
 * owns the grid's re-render loop) stays in control of when to redraw.
 */
export function renderTile(shot, renaming) {
  const wrap = el("div");

  const tile = el("div", "tile");
  tile.addEventListener("click", () => invoke("open_screenshot", { path: shot.path }));
  thumbnailUrl(shot.path, 240).then((url) => {
    if (url) tile.appendChild(el("img")).src = url;
  });

  const scrim = el("div", "scrim");
  scrim.appendChild(overlayButton(ICONS.copy, "Copy", () => invoke("copy_screenshot", { path: shot.path })));
  scrim.appendChild(overlayButton(ICONS.folder, "Reveal", () => invoke("reveal_screenshot", { path: shot.path })));
  scrim.appendChild(overlayButton(ICONS.trash, "Delete", () => deleteShot(shot)));
  tile.appendChild(scrim);
  wrap.appendChild(tile);

  wrap.appendChild(renderName(shot, renaming));

  const meta = el("div", "shot-meta");
  meta.appendChild(el("span", "", timeLabel(shot.created_at)));
  meta.appendChild(el("span", "", sourceLabel(shot)));
  wrap.appendChild(meta);

  return wrap;
}

function overlayButton(iconPath, label, onClick) {
  const btn = el("button", "overlay-btn");
  btn.title = label;
  btn.innerHTML = svgIcon(iconPath);
  btn.addEventListener("click", (e) => {
    e.stopPropagation();
    onClick();
  });
  return btn;
}

function renderName(shot, renaming) {
  const box = el("div", "shot-name");
  if (renaming.id === shot.id) {
    const input = document.createElement("input");
    input.value = shot.name;
    input.spellcheck = false;
    box.appendChild(input);
    setTimeout(() => {
      input.focus();
      input.select();
    });
    const commit = () => {
      renaming.setId(null);
      const value = input.value.trim();
      if (value && value !== shot.name) {
        invoke("rename_screenshot", { id: shot.id, newName: value });
      }
    };
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") commit();
      if (e.key === "Escape") renaming.setId(null);
    });
    input.addEventListener("blur", commit);
  } else {
    box.textContent = shot.name;
    box.title = "Double-click to rename";
    box.addEventListener("dblclick", () => renaming.setId(shot.id));
  }
  return box;
}

async function deleteShot(shot) {
  try {
    await invoke("delete_screenshot", { id: shot.id });
  } catch (err) {
    console.error(err);
  }
}
