import { el, invoke } from "./shared.js";

/** Settings line for the on/off switch of automatic updates. */
export async function createAutoUpdateRow() {
  const row = el("label", "row");
  const box = document.createElement("input");
  box.type = "checkbox";
  box.checked = await invoke("get_auto_update");
  box.addEventListener("change", () => invoke("set_auto_update", { enabled: box.checked }));
  row.append(el("span", "label", "Install updates automatically"), box);
  return row;
}
