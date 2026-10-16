import { el, invoke } from "./shared.js";

// Keys that type nothing, so they may be bound without a modifier.
const STANDALONE_KEY = /^(F([1-9]|1\d|2[0-4])|PrintScreen|ScrollLock|Pause)$/;
const MODIFIER_CODES = ["Control", "Alt", "Shift", "Meta"];

// Only one row records at a time; starting another cancels the first.
let cancelActive = null;

function comboFrom(e) {
  const mods = [];
  if (e.ctrlKey) mods.push("Ctrl");
  if (e.altKey) mods.push("Alt");
  if (e.shiftKey) mods.push("Shift");
  if (e.metaKey) mods.push("Super");
  return [...mods, e.code].join("+");
}

/** One Settings line: label, a click-to-record field and a Reset button. */
export function createHotkeyRow({ action, label, display }, showError) {
  const row = el("div", "row");
  const field = el("button", "hotkey-field");
  const reset = el("button", "reset-btn", "Reset");
  row.append(el("span", "label", label), field, reset);

  let current = display;

  /** Draws the combination as keycaps ("Ctrl + /" becomes two keys). */
  function showKeys(combo) {
    field.replaceChildren(...combo.split(" + ").map((part) => el("span", "key", part)));
  }
  showKeys(current);

  function stop() {
    field.classList.remove("recording");
    showKeys(current);
    document.removeEventListener("keydown", onKey, true);
    document.removeEventListener("keyup", onKey, true);
    cancelActive = null;
  }

  async function onKey(e) {
    e.preventDefault();
    // Webviews report PrintScreen on keyup only.
    if (e.type === "keyup" && e.code !== "PrintScreen") return;
    if (MODIFIER_CODES.some((m) => e.code.startsWith(m))) return; // wait for the real key

    const hasModifier = e.ctrlKey || e.altKey || e.shiftKey || e.metaKey;
    if (e.code === "Escape" && !hasModifier) return stop();
    if (!hasModifier && !STANDALONE_KEY.test(e.code)) return;

    const combo = comboFrom(e);
    stop();
    try {
      current = await invoke("set_hotkey", { action, hotkeyStr: combo });
      showError("");
    } catch (err) {
      showError(String(err));
    }
    showKeys(current);
  }

  field.addEventListener("click", () => {
    if (field.classList.contains("recording")) return;
    cancelActive?.();
    showError("");
    field.textContent = "Press a key combination…";
    field.classList.add("recording");
    document.addEventListener("keydown", onKey, true);
    document.addEventListener("keyup", onKey, true);
    cancelActive = stop;
  });

  reset.addEventListener("click", async () => {
    try {
      current = await invoke("reset_hotkey", { action });
      showError("");
    } catch (err) {
      showError(String(err));
    }
    showKeys(current);
  });

  return row;
}
