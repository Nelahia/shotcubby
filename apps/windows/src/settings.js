import { el, invoke, svgIcon, ICONS } from "./shared.js";
import { createHotkeyRow } from "./hotkey-row.js";
import { createOrganizeRow } from "./organize-row.js";
import { createAutoUpdateRow } from "./auto-update-row.js";
import { createUpdateRow } from "./update-row.js";
import { createVaultRow } from "./vault-row.js";

const rows = document.getElementById("rows");
const errorEl = document.getElementById("error");
const footerEl = document.getElementById("footer-text");
const titleEl = document.getElementById("page-title");
const sidebar = document.getElementById("sidebar");

const showError = (message) => {
  errorEl.textContent = message;
};

const SHORTCUTS_HELP =
  "Click a field, then press the combination you want: a modifier (Ctrl, Alt, Shift, Win) plus a key, or a lone function / PrintScreen key. Esc cancels.";

/** The sidebar entries; each builds its rows when opened. */
const PAGES = [
  {
    title: "General",
    icon: ICONS.gear,
    build: async () => [await createAutoUpdateRow(), await createUpdateRow()],
  },
  {
    title: "Screenshots",
    icon: ICONS.folder,
    build: async () => [await createVaultRow(), await createOrganizeRow()],
  },
  {
    title: "Shortcuts",
    icon: ICONS.keyboard,
    footer: SHORTCUTS_HELP,
    build: async () => (await invoke("get_hotkeys")).map((hotkey) => createHotkeyRow(hotkey, showError)),
  },
];

async function open(page, button) {
  sidebar.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("selected", item === button));
  titleEl.textContent = page.title;
  errorEl.textContent = "";
  footerEl.textContent = page.footer ?? "";
  rows.replaceChildren(...(await page.build()));
}

function load() {
  const buttons = PAGES.map((page) => {
    const button = el("button", "nav-item");
    button.innerHTML = svgIcon(page.icon);
    button.append(page.title);
    button.addEventListener("click", () => open(page, button));
    return button;
  });
  sidebar.replaceChildren(...buttons);
  open(PAGES[0], buttons[0]);
}

load();
