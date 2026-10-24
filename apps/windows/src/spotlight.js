import { invoke, listen, currentWindow, el, GLYPH_SVG } from "./shared.js";
import { renderRow } from "./spotlight-row.js";
import { createSpotlightFooter } from "./spotlight-footer.js";
import { createSpotlightActions } from "./spotlight-actions.js";
import { createContextMenu } from "./spotlight-context-menu.js";
import { renderPreview } from "./spotlight-preview.js";
import { watchScreenshotChanges } from "./spotlight-sync.js";

const state = {
  shots: [],
  query: "",
  selection: null,
  renamingId: null,
};

document.querySelector("#search-row .glyph").innerHTML = GLYPH_SVG;
const searchInput = document.getElementById("search-input");

function results() {
  const q = state.query.trim().toLowerCase();
  const sorted = [...state.shots].sort((a, b) => b.created_at - a.created_at);
  const matched = q ? sorted.filter((s) => s.name.toLowerCase().includes(q)) : sorted;
  return matched.slice(0, 60);
}

function selected() {
  return results().find((s) => s.id === state.selection) ?? null;
}

function move(delta) {
  const list = results();
  if (list.length === 0) return;
  const current = list.findIndex((s) => s.id === state.selection);
  const next = Math.max(0, Math.min(list.length - 1, (current < 0 ? 0 : current) + delta));
  state.selection = list[next].id;
  updateSelection();
}

async function reset() {
  state.shots = await invoke("list_screenshots");
  state.query = "";
  state.renamingId = null;
  const list = results();
  state.selection = list[0]?.id ?? null;
  searchInput.value = "";
  footer.close();
  contextMenu.hide();
  render();
  searchInput.focus();
}

// A rename changes a screenshot's id (it is its path): old id -> new id, so a
// row still being edited when AI naming renames it can find its screenshot.
const movedIds = new Map();
let syncSeq = 0;

/** Refreshes the list in place while the Spotlight stays open: query and selection are kept. */
async function syncShots(renamed) {
  if (renamed) {
    movedIds.set(renamed.old_id, renamed.item.id);
    if (state.selection === renamed.old_id) state.selection = renamed.item.id;
  }
  const seq = ++syncSeq;
  const shots = await invoke("list_screenshots");
  // Answers can arrive out of order: only the newest refresh is applied.
  if (seq !== syncSeq) return;
  state.shots = shots;
  if (!results().some((s) => s.id === state.selection)) state.selection = results()[0]?.id ?? null;
  // Rebuilding the rows would drop the input the user is typing a name into.
  if (!state.renamingId) render();
}

function render() {
  const list = results();
  document.getElementById("result-count").textContent = String(list.length);

  const listEl = document.getElementById("list");
  const previewEl = document.getElementById("preview");
  const emptyEl = document.getElementById("spot-empty");

  if (list.length === 0) {
    listEl.hidden = true;
    previewEl.hidden = true;
    emptyEl.hidden = false;
    emptyEl.innerHTML = "";
    emptyEl.appendChild(
      el("div", "", state.query ? `No screenshot named "${state.query}"` : "No screenshots yet")
    );
    emptyEl.appendChild(el("div", "", state.query ? "Try fewer letters." : "Press Win+Shift+S and it lands here."));
    return;
  }

  listEl.hidden = false;
  previewEl.hidden = false;
  emptyEl.hidden = true;

  const rowCallbacks = {
    onSelect: (shot) => {
      state.selection = shot.id;
      state.renamingId = null;
      footer.close();
      render();
    },
    onOpen: previewSelected,
    onCommitRename: commitRename,
    onCancelRename: () => {
      state.renamingId = null;
      render();
    },
    onContextMenu: (shot, x, y) => {
      footer.close();
      contextMenu.show(x, y);
    },
  };

  listEl.textContent = "";
  for (const shot of list) {
    listEl.appendChild(
      renderRow(shot, shot.id === state.selection, shot.id === state.renamingId, rowCallbacks)
    );
  }

  renderPreview(previewEl, selected(), (shot) => shot.id === state.selection);

  const selectedRow = listEl.querySelector(".row.selected");
  if (selectedRow) selectedRow.scrollIntoView({ block: "nearest" });
}

/**
 * Arrow-key navigation only changes which row is highlighted: moving the
 * `.selected` class and refreshing the preview, instead of rebuilding every
 * row (which re-requested all thumbnails and made the whole list flicker).
 */
function updateSelection() {
  const listEl = document.getElementById("list");
  listEl.querySelector(".row.selected")?.classList.remove("selected");
  const row = [...listEl.children].find((r) => r.dataset.id === state.selection);
  row?.classList.add("selected");
  row?.scrollIntoView({ block: "nearest" });
  renderPreview(document.getElementById("preview"), selected(), (shot) => shot.id === state.selection);
}

async function commitRename(shot, newName) {
  state.renamingId = null;
  const trimmed = newName.trim();
  if (trimmed && trimmed !== shot.name) {
    try {
      const renamed = await invoke("rename_screenshot", { id: movedIds.get(shot.id) ?? shot.id, newName: trimmed });
      state.selection = renamed.id;
    } catch (err) {
      // Without this the row stayed stuck on its input with no explanation.
      console.error(err);
      window.alert(String(err));
    }
    state.shots = await invoke("list_screenshots");
  }
  render();
}

function beginRename() {
  const shot = selected();
  if (shot) {
    state.renamingId = shot.id;
    render();
  }
}

const { copySelected, previewSelected, revealSelected, deleteSelected } = createSpotlightActions({
  getSelected: selected,
  onDeleted: (shot) => {
    state.shots = state.shots.filter((s) => s.id !== shot.id);
    const list = results();
    state.selection = list[0]?.id ?? null;
    render();
  },
});

function closeOrClearSearch() {
  if (state.query) {
    state.query = "";
    searchInput.value = "";
    render();
  } else {
    currentWindow().hide();
  }
}

searchInput.addEventListener("input", () => {
  state.query = searchInput.value;
  const list = results();
  state.selection = list[0]?.id ?? null;
  footer.close();
  contextMenu.hide();
  render();
});

/** Ctrl+C copies the screenshot, unless text is selected in the search box (then it is a plain text copy). */
function hasSelectedSearchText() {
  return document.activeElement === searchInput && searchInput.selectionStart !== searchInput.selectionEnd;
}

document.addEventListener("keydown", (e) => {
  if (state.renamingId) return; // the row's own input handles Enter/Escape

  const ctrl = e.ctrlKey || e.metaKey;

  if (contextMenu.isOpen()) {
    if (e.key === "Escape") {
      e.preventDefault();
      contextMenu.hide();
    }
    return;
  }

  if (footer.isOpen()) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      footer.moveHighlight(1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      footer.moveHighlight(-1);
    } else if (e.key === "Enter") {
      e.preventDefault();
      footer.runHighlighted();
    } else if (e.key === "Escape" || (ctrl && e.key.toLowerCase() === "k")) {
      e.preventDefault();
      footer.close();
    }
    return;
  }

  if (e.key === "ArrowDown") {
    e.preventDefault();
    move(1);
  } else if (e.key === "ArrowUp") {
    e.preventDefault();
    move(-1);
  } else if (e.key === "Enter") {
    e.preventDefault();
    previewSelected();
  } else if (e.key === "Escape") {
    e.preventDefault();
    closeOrClearSearch();
  } else if (ctrl && e.key.toLowerCase() === "k") {
    e.preventDefault();
    footer.toggle();
  } else if (ctrl && e.key.toLowerCase() === "r") {
    e.preventDefault();
    revealSelected();
  } else if (ctrl && e.key.toLowerCase() === "c" && !hasSelectedSearchText()) {
    e.preventDefault();
    copySelected();
  } else if (ctrl && e.key.toLowerCase() === "e") {
    e.preventDefault();
    beginRename();
  } else if (ctrl && e.key === ",") {
    e.preventDefault();
    invoke("open_settings_window");
  } else if (ctrl && e.key === "Backspace") {
    e.preventDefault();
    deleteSelected();
  }
});

listen("spotlight-shown", reset);
watchScreenshotChanges(syncShots);

const footer = createSpotlightFooter(document.getElementById("hints"), {
  copy: copySelected,
  preview: previewSelected,
  reveal: revealSelected,
  rename: beginRename,
  trash: deleteSelected,
  settings: () => invoke("open_settings_window"),
});

const itemActions = [
  { keys: "↩", label: "Preview", run: previewSelected },
  { keys: "Ctrl C", label: "Copy", run: copySelected },
  { keys: "Ctrl E", label: "Rename", run: beginRename },
  { keys: "Ctrl R", label: "Open Folder", run: revealSelected },
  { keys: "Ctrl ⌫", label: "Move to Trash", run: deleteSelected, destructive: true },
];
const contextMenu = createContextMenu(document.getElementById("context-menu"), itemActions);

reset();
