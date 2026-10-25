import { el, invoke, svgIcon, ICONS, GLYPH_SVG, card } from "./shared.js";
import { createAppearanceRow } from "./appearance-row.js";
import { createLaunchRow } from "./launch-row.js";
import { createHotkeyRow } from "./hotkey-row.js";
import { createOrganizeRow } from "./organize-row.js";
import { createAutoUpdateRow } from "./auto-update-row.js";
import { createUpdateRow } from "./update-row.js";
import { createVaultRow } from "./vault-row.js";
import { buildAiRenamePage } from "./ai-rename-page.js";

const rows = document.getElementById("rows");
const errorEl = document.getElementById("error");
const subtitleEl = document.getElementById("page-subtitle");
const titleEl = document.getElementById("page-title");
const sidebar = document.getElementById("sidebar");

const showError = (message) => {
  errorEl.textContent = message;
};

/** The sidebar entries; each builds its blocks (cards, alerts…) when opened. */
const PAGES = [
  {
    title: "General",
    subtitle: "Appearance, startup, updates and the version you are running.",
    icon: ICONS.gear,
    build: async () => [
      card(await createAppearanceRow(), await createLaunchRow(), await createAutoUpdateRow(), await createUpdateRow()),
    ],
  },
  {
    title: "Screenshots",
    subtitle: "Where your screenshots live, and how they are filed.",
    icon: ICONS.folder,
    build: async () => [card(await createVaultRow(), await createOrganizeRow())],
  },
  {
    title: "AI naming",
    subtitle:
      "New screenshots are renamed after what they show, using your own AI key. Nothing is sent while this is off.",
    icon: ICONS.sparkle,
    build: buildAiRenamePage,
  },
  {
    title: "Shortcuts",
    subtitle:
      "Click a combination, then press the keys you want: a modifier (Ctrl, Alt, Shift, Win) plus a key, or a lone function / PrintScreen key. Esc cancels.",
    icon: ICONS.keyboard,
    build: async () => [card(...(await invoke("get_hotkeys")).map((hotkey) => createHotkeyRow(hotkey, showError)))],
  },
];

async function open(page, button) {
  sidebar.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("selected", item === button));
  titleEl.textContent = page.title;
  subtitleEl.textContent = page.subtitle;
  errorEl.textContent = "";
  rows.replaceChildren(...(await page.build()));
}

function brand() {
  const node = el("div", "brand");
  const mark = el("span", "brand-mark");
  mark.innerHTML = GLYPH_SVG;
  node.append(mark, "ShotCubby");
  return node;
}

function load() {
  const buttons = PAGES.map((page) => {
    const button = el("button", "nav-item");
    button.innerHTML = svgIcon(page.icon);
    button.append(page.title);
    button.addEventListener("click", () => open(page, button));
    return button;
  });
  sidebar.replaceChildren(brand(), ...buttons);
  open(PAGES[0], buttons[0]);
}

load();
