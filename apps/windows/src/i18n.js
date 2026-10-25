import { FR } from "./locales/fr.js";

const tauri = window.__TAURI__;

async function currentLanguage() {
  try {
    return await tauri.core.invoke("get_language");
  } catch {
    return "en";
  }
}

const language = await currentLanguage();
const table = language === "fr" ? FR : {};

/** Argument for `toLocale…String`: French when the app is, the system's own otherwise. */
export const dateLocale = language === "fr" ? "fr" : [];

/**
 * The text in the app's language. The English text is the key: a text with no
 * French entry is shown in English. `{name}` marks a value taken from `values`.
 */
export function t(english, values) {
  const text = table[english] ?? english;
  return values ? text.replace(/\{(\w+)\}/g, (_, name) => values[name] ?? "") : text;
}

/** Translates what a page fixes in its HTML: `data-i18n` (text), `data-i18n-title`, `data-i18n-placeholder`. */
function translatePage() {
  document.querySelectorAll("[data-i18n]").forEach((node) => (node.textContent = t(node.textContent.trim())));
  for (const attribute of ["title", "placeholder"]) {
    document.querySelectorAll(`[data-i18n-${attribute}]`).forEach((node) => {
      node.setAttribute(attribute, t(node.getAttribute(`data-i18n-${attribute}`)));
    });
  }
}

translatePage();
tauri.event.listen("language-changed", () => location.reload());
