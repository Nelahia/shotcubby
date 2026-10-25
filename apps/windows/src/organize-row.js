import { el, invoke } from "./shared.js";
import { t } from "./i18n.js";

/** Settings line for filing past days' screenshots into dated folders. */
export async function createOrganizeRow() {
  const row = el("label", "row");
  const box = document.createElement("input");
  box.type = "checkbox";
  box.checked = await invoke("get_organize_by_day");
  box.addEventListener("change", () => invoke("set_organize_by_day", { enabled: box.checked }));
  const text = el("div", "label");
  text.append(
    el("div", "", t("File past days into dated folders")),
    el("div", "status", t("Today's screenshots stay in the main folder; older ones move to YYYY-MM-DD.")),
  );
  row.append(text, box);
  return row;
}
