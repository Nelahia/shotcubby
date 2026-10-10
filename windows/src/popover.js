import { invoke, listen, currentWindow, el, svgIcon, ICONS, GLYPH_SVG, dayLabel } from "./shared.js";
import { renderTile } from "./screenshot-tile.js";
import { renderAccessCard } from "./access-card.js";

const FILTERS = [
  { id: "all", label: "All", matches: () => true },
  { id: "files", label: "Files", matches: (s) => s.source !== "clipboard" },
  { id: "clipboard", label: "Clipboard", matches: (s) => s.source === "clipboard" },
];

const state = {
  shots: [],
  filter: "all",
  accessFailure: null,
  renamingId: null,
  screenshotDir: "",
  vaultDir: "",
};

const renaming = {
  get id() {
    return state.renamingId;
  },
  setId(id) {
    state.renamingId = id;
    render();
  },
};

document.querySelector("#header .glyph").innerHTML = GLYPH_SVG;
document.getElementById("settings-btn").innerHTML = svgIcon(ICONS.gear);
document.querySelector("#spotlight-btn span").innerHTML = svgIcon(ICONS.search);

async function refresh() {
  const [shots, accessFailure, hotkey, screenshotDir, vaultDir] = await Promise.all([
    invoke("list_screenshots"),
    invoke("get_access_failure"),
    invoke("get_hotkey"),
    invoke("get_screenshot_dir"),
    invoke("get_vault_dir"),
  ]);
  state.shots = shots;
  state.accessFailure = accessFailure;
  state.screenshotDir = screenshotDir;
  state.vaultDir = vaultDir;
  document.getElementById("spotlight-kbd").textContent = hotkey.display;
  render();
}

function visibleShots() {
  const filter = FILTERS.find((f) => f.id === state.filter);
  return state.shots.filter(filter.matches);
}

function render() {
  const visible = visibleShots();
  document.getElementById("count").textContent = String(visible.length);

  const accessCard = document.getElementById("access-card");
  const filterBar = document.getElementById("filter-bar");
  if (state.accessFailure) {
    accessCard.hidden = false;
    filterBar.hidden = true;
    renderAccessCard(
      accessCard,
      state.accessFailure,
      { screenshotDir: state.screenshotDir, vaultDir: state.vaultDir },
      refresh
    );
  } else {
    accessCard.hidden = true;
    filterBar.hidden = false;
    renderFilterBar(filterBar);
  }

  renderContent(visible);
}

function renderFilterBar(bar) {
  bar.textContent = "";
  for (const filter of FILTERS) {
    const count = state.shots.filter(filter.matches).length;
    const btn = el("button", filter.id === state.filter ? "on" : "");
    btn.append(filter.label + " ");
    btn.appendChild(el("span", "n", String(count)));
    btn.addEventListener("click", () => {
      state.filter = filter.id;
      render();
    });
    bar.appendChild(btn);
  }
}

function renderContent(visible) {
  const empty = document.getElementById("empty-state");
  const groupsEl = document.getElementById("groups");

  if (visible.length === 0) {
    empty.hidden = false;
    groupsEl.hidden = true;
    empty.innerHTML = "";
    const glyph = el("div", "glyph");
    glyph.innerHTML = GLYPH_SVG;
    empty.appendChild(glyph);
    empty.appendChild(el("div", "", "No screenshots yet"));
    empty.appendChild(el("div", "", "Press Win+Shift+S and it lands here."));
    return;
  }

  empty.hidden = true;
  groupsEl.hidden = false;
  groupsEl.textContent = "";

  const byDay = new Map();
  for (const shot of [...visible].sort((a, b) => b.created_at - a.created_at)) {
    const label = dayLabel(shot.created_at);
    if (!byDay.has(label)) byDay.set(label, []);
    byDay.get(label).push(shot);
  }

  for (const [label, shots] of byDay) {
    groupsEl.appendChild(el("div", "day-label", label));
    const grid = el("div", "grid");
    for (const shot of shots) grid.appendChild(renderTile(shot, renaming));
    groupsEl.appendChild(grid);
  }
}

document.getElementById("settings-btn").addEventListener("click", () => invoke("open_settings_window"));
document.getElementById("spotlight-btn").addEventListener("click", () => invoke("open_spotlight_from_popover"));
document.getElementById("quit-btn").addEventListener("click", () => invoke("quit_app"));

listen("screenshot-added", refresh);
listen("screenshot-removed", refresh);
listen("screenshot-renamed", refresh);
listen("access-failure-changed", refresh);

currentWindow().onFocusChanged(({ payload: focused }) => {
  if (focused) refresh();
});

refresh();
