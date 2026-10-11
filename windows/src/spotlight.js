import { invoke, listen, currentWindow, el, svgIcon, GLYPH_SVG, ICONS } from "./shared.js";
import { renderRow } from "./spotlight-row.js";
import { createSpotlightFooter } from "./spotlight-footer.js";
import { createSpotlightActions } from "./spotlight-actions.js";
import { createContextMenu } from "./spotlight-context-menu.js";
import { renderPreview } from "./spotlight-preview.js";

const state = {
  shots: [],
  query: "",
  selection: null,
  renamingId: null,
  copiedId: null,
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
  state.copiedId = null;
  const list = results();
  state.selection = list[0]?.id ?? null;
  searchInput.value = "";
  footer.close();
  contextMenu.hide();
  hideCopyFlash();
  render();
  searchInput.focus();
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
      renderRow(shot, shot.id === state.selection, shot.id === state.renamingId, shot.id === state.copiedId, rowCallbacks)
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
    const renamed = await invoke("rename_screenshot", { id: shot.id, newName: trimmed });
    state.shots = await invoke("list_screenshots");
    state.selection = renamed.id;
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

const copyFlashEl = document.getElementById("copy-flash");
copyFlashEl.innerHTML = `${svgIcon(ICONS.check)}<span>Copied</span>`;
copyFlashEl.addEventListener("animationend", () => {
  copyFlashEl.hidden = true;
});

function showCopyFlash() {
  copyFlashEl.hidden = false;
  copyFlashEl.classList.remove("flash");
  void copyFlashEl.offsetWidth; // restart the animation on back-to-back copies
  copyFlashEl.classList.add("flash");
}

function hideCopyFlash() {
  copyFlashEl.hidden = true;
  copyFlashEl.classList.remove("flash");
}

const { copySelected, previewSelected, revealSelected, deleteSelected } = createSpotlightActions({
  getSelected: selected,
  onCopied: (shot) => {
    state.copiedId = shot.id;
    showCopyFlash();
    render();
  },
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
  } else if (ctrl && e.key.toLowerCase() === "c" && document.activeElement !== searchInput) {
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
