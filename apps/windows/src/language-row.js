import { el, invoke } from "./shared.js";
import { t } from "./i18n.js";

// Language names are shown in their own language, whatever the app speaks.
const CHOICES = [
  ["auto", t("Auto")],
  ["en", "English"],
  ["fr", "Français"],
];

/** Settings line to follow Windows' language or force English or French. */
export async function createLanguageRow() {
  const row = el("div", "row");
  const segmented = el("div", "seg");
  segmented.setAttribute("role", "group");
  segmented.setAttribute("aria-label", t("Language"));

  const buttons = CHOICES.map(([id, label]) => {
    const button = el("button", "", label);
    // Every window reloads in the new language once it is saved.
    button.addEventListener("click", () => invoke("set_language_preference", { preference: id }));
    return { id, button };
  });

  segmented.append(...buttons.map(({ button }) => button));
  const selected = await invoke("get_language_preference");
  buttons.forEach(({ id, button }) => button.setAttribute("aria-pressed", String(id === selected)));
  row.append(el("div", "label", t("Language")), segmented);
  return row;
}
