import { el, invoke } from "./shared.js";

/** Settings line for the on/off switch of AI naming. Off until the user opts in. */
export function createAiRenameRow(state) {
  const row = el("label", "row");
  const box = document.createElement("input");
  box.type = "checkbox";
  box.setAttribute("aria-label", "Name new screenshots with AI");
  box.checked = state.enabled;
  box.addEventListener("change", () => invoke("set_ai_rename_enabled", { enabled: box.checked }));
  const text = el("div", "label");
  text.append(
    el("div", "", "Name new screenshots with AI"),
    el("div", "status", "A downscaled copy of each capture goes to your provider."),
  );
  row.append(text, box);
  return row;
}
