const tauri = window.__TAURI__;
export const invoke = (cmd, args) => tauri.core.invoke(cmd, args);
export const listen = (event, handler) => tauri.event.listen(event, handler);
export const currentWindow = () => tauri.window.getCurrentWindow();
export const appVersion = () => tauri.app.getVersion();

export function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text != null) node.textContent = text;
  return node;
}

export function svgIcon(path) {
  return `<svg class="icon" viewBox="0 0 24 24">${path}</svg>`;
}

export const ICONS = {
  copy: '<rect x="8.5" y="8.5" width="11" height="11" rx="2.5"></rect><path d="M15.5 5.5v-.5a2 2 0 0 0-2-2H6.5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h.5"></path>',
  folder: '<path d="M3.5 7a2 2 0 0 1 2-2h3.5l2 2h7.5a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"></path>',
  trash: '<path d="M4.5 7h15M9.5 7V5a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v2M6.5 7l.8 11a2 2 0 0 0 2 1.9h5.4a2 2 0 0 0 2-1.9l.8-11"></path>',
  gear: '<circle cx="12" cy="12" r="3"></circle><path d="M19.4 13a7.6 7.6 0 0 0 0-2l2-1.5-2-3.4-2.3 1a7.7 7.7 0 0 0-1.7-1l-.3-2.6h-4l-.3 2.6a7.7 7.7 0 0 0-1.7 1l-2.3-1-2 3.4L6.6 11a7.6 7.6 0 0 0 0 2l-2 1.5 2 3.4 2.3-1a7.7 7.7 0 0 0 1.7 1l.3 2.6h4l.3-2.6a7.7 7.7 0 0 0 1.7-1l2.3 1 2-3.4z"></path>',
  search: '<circle cx="11" cy="11" r="6.5"></circle><path d="M16 16l4.5 4.5"></path>',
  check: '<path d="M5 12.5l4.5 4.5L19 7"></path>',
  keyboard: '<rect x="2.5" y="6" width="19" height="12" rx="2.5"></rect><path d="M6.5 10h.01M10 10h.01M13.5 10h.01M17 10h.01M7.5 14h9"></path>',
};

/** Brackets-around-a-kept-shot glyph, ported from `ShotCubbyGlyph` (SwiftUI Canvas). */
export const GLYPH_SVG = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">
  <path stroke-width="2" d="M3 8V5.5A2.5 2.5 0 0 1 5.5 3H8M16 3h2.5A2.5 2.5 0 0 1 21 5.5V8M21 16v2.5a2.5 2.5 0 0 1-2.5 2.5H16M8 21H5.5A2.5 2.5 0 0 1 3 18.5V16"/>
  <path stroke-width="1.75" d="M9.5 7.25h5"/>
  <rect x="7" y="9.75" width="10" height="7.25" rx="1.75" fill="currentColor" stroke="none"/>
</svg>`;

export function timeLabel(ms) {
  return new Date(ms).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
}

export function dayLabel(ms) {
  const date = new Date(ms);
  const now = new Date();
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const diffDays = Math.round((startOfDay(now) - startOfDay(date)) / 86400000);
  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  return date.toLocaleDateString([], { day: "numeric", month: "long" });
}

export function relativeLabel(ms) {
  const diff = Date.now() - ms;
  const minute = 60000;
  const hour = 60 * minute;
  const day = 24 * hour;
  if (diff < minute) return "just now";
  if (diff < hour) return `${Math.round(diff / minute)} min ago`;
  if (diff < day) return `${Math.round(diff / hour)} hr ago`;
  if (diff < 2 * day) return "yesterday";
  return `${Math.round(diff / day)} days ago`;
}

/** File name (with extension) of a screenshot, without its folders. */
export function fileName(item) {
  return item.path.split(/[\\/]/).pop();
}

export function sourceLabel(item) {
  if (item.source === "clipboard") return "Clipboard";
  const name = fileName(item);
  const dot = name.lastIndexOf(".");
  return dot >= 0 ? name.slice(dot + 1).toUpperCase() : "";
}

const THUMBNAIL_CACHE_LIMIT = 200;
const thumbnailCache = new Map();

/**
 * Cached per (path, size): lists re-request every thumbnail on each rebuild,
 * and an uncached round trip to the backend leaves the image blank for a
 * frame — visible as flicker. A failed load is not kept, so it can retry.
 */
export function thumbnailUrl(path, maxPx) {
  const key = `${path}|${maxPx}`;
  let pending = thumbnailCache.get(key);
  if (!pending) {
    pending = invoke("get_thumbnail", { path, maxPx }).catch(() => null);
    pending.then((url) => {
      if (url === null) thumbnailCache.delete(key);
    });
    thumbnailCache.set(key, pending);
    if (thumbnailCache.size > THUMBNAIL_CACHE_LIMIT) {
      thumbnailCache.delete(thumbnailCache.keys().next().value);
    }
  }
  return pending;
}
