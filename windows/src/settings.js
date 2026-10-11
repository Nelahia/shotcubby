import { invoke, appVersion } from "./shared.js";
import { createHotkeyRow } from "./hotkey-row.js";
import { createAutoUpdateRow } from "./auto-update-row.js";

const rows = document.getElementById("rows");
const errorEl = document.getElementById("error");
const versionEl = document.getElementById("version");

const showError = (message) => {
  errorEl.textContent = message;
};

async function load() {
  const hotkeys = await invoke("get_hotkeys");
  rows.replaceChildren(
    ...hotkeys.map((hotkey) => createHotkeyRow(hotkey, showError)),
    await createAutoUpdateRow(),
  );
}

appVersion().then((v) => (versionEl.textContent = `ShotCubby ${v}`));
load();
