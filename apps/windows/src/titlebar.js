import { el, currentWindow } from "./shared.js";

const ICON_MINIMIZE = '<svg viewBox="0 0 10 10"><path d="M1 5h8"></path></svg>';
const ICON_CLOSE = '<svg viewBox="0 0 10 10"><path d="M1.5 1.5l7 7M8.5 1.5l-7 7"></path></svg>';

function control(label, icon, className, onClick) {
  const button = el("button", `win-btn ${className}`.trim());
  button.type = "button";
  button.title = label;
  button.setAttribute("aria-label", label);
  button.innerHTML = icon;
  button.addEventListener("click", onClick);
  return button;
}

/** The Settings window's own title bar: a drag area with Minimize and Close. */
export function createTitleBar() {
  const bar = el("header", "titlebar");
  bar.dataset.tauriDragRegion = "";
  bar.append(
    control("Minimize", ICON_MINIMIZE, "", () => currentWindow().minimize()),
    control("Close", ICON_CLOSE, "close", () => currentWindow().hide()),
  );
  return bar;
}
