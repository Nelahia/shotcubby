import { invoke, fitWindowToContent } from "./shared.js";
import { createHotkeyRow } from "./hotkey-row.js";
import { createAutoUpdateRow } from "./auto-update-row.js";
import { createUpdateRow } from "./update-row.js";

const rows = document.getElementById("rows");
const errorEl = document.getElementById("error");

const showError = (message) => {
  errorEl.textContent = message;
};

async function load() {
  const hotkeys = await invoke("get_hotkeys");
  rows.replaceChildren(
    ...hotkeys.map((hotkey) => createHotkeyRow(hotkey, showError)),
    await createAutoUpdateRow(),
    await createUpdateRow(),
  );
  await fitWindowToContent(500);
}

load();
