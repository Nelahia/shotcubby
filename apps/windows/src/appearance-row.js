import { el, invoke } from "./shared.js";

const CHOICES = [
  ["light", "Light"],
  ["dark", "Dark"],
];

/** Settings line to switch every window between the light and dark look. */
export async function createAppearanceRow() {
  const row = el("div", "row");
  const segmented = el("div", "seg");
  segmented.setAttribute("role", "group");
  segmented.setAttribute("aria-label", "Appearance");

  const buttons = CHOICES.map(([id, label]) => {
    const button = el("button", "", label);
    button.addEventListener("click", async () => {
      await invoke("set_theme", { theme: id });
      select(id);
    });
    return { id, button };
  });

  function select(theme) {
    buttons.forEach(({ id, button }) => button.setAttribute("aria-pressed", String(id === theme)));
  }

  segmented.append(...buttons.map(({ button }) => button));
  select(await invoke("get_theme"));
  row.append(el("div", "label", "Appearance"), segmented);
  return row;
}
