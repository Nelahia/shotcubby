import { el, thumbnailUrl } from "./shared.js";

/**
 * Fills the preview pane for `current`. The image element is reused across
 * calls and keeps showing the previous picture until the next one is ready,
 * so moving through the list never flashes an empty pane.
 * `isStillCurrent` drops a load that finished after the selection moved on.
 */
export function renderPreview(previewEl, current, isStillCurrent) {
  if (!current) {
    previewEl.textContent = "";
    return;
  }

  let img = previewEl.querySelector("img");
  if (!img) {
    img = el("img");
    previewEl.append(img, el("div", "file"), el("div", "sub"));
  }

  thumbnailUrl(current.path, 420).then((url) => {
    if (url && isStillCurrent(current)) img.src = url;
  });
  previewEl.querySelector(".file").textContent = current.id;
  previewEl.querySelector(".sub").textContent = `${new Date(current.created_at).toLocaleString()} · ${
    current.source === "clipboard" ? "from clipboard" : "file"
  }`;
}
