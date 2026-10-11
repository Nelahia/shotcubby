import { invoke } from "./shared.js";
import { createHotkeyRow } from "./hotkey-row.js";

const rows = document.getElementById("rows");
const errorEl = document.getElementById("error");

const showError = (message) => {
  errorEl.textContent = message;
};

async function load() {
  const hotkeys = await invoke("get_hotkeys");
  rows.replaceChildren(...hotkeys.map((hotkey) => createHotkeyRow(hotkey, showError)));
}

load();
