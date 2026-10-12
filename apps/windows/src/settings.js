import { invoke, fitWindowToContent } from "./shared.js";
import { createHotkeyRow } from "./hotkey-row.js";
import { createOrganizeRow } from "./organize-row.js";
import { createVaultRow } from "./vault-row.js";
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
    await createVaultRow(),
    await createOrganizeRow(),
    await createAutoUpdateRow(),
    await createUpdateRow(),
  );
  await fitWindowToContent(560, 600);
}

load();
