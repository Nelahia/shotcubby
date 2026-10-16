import { el, invoke, svgIcon, ICONS } from "./shared.js";

const POLL_MS = 2000;

/**
 * Card showing what the last AI naming attempt did; refreshes while the page
 * is open. A new failure is also handed to `onFailure` so the page can explain
 * it in an alert (once per distinct failure).
 */
export function createAiLastResultRow(state, onFailure) {
  const card = el("section", "result");
  const icon = el("span", "result-icon");
  const text = el("div");
  const line = el("div", "result-text");
  text.append(el("div", "result-label", "Last result"), line);
  card.append(icon, text);

  let alerted = null;

  function show(result, provider) {
    const failed = !!result && !result.ok;
    card.classList.toggle("bad", failed);
    icon.innerHTML = svgIcon(failed ? ICONS.alert : ICONS.check);
    line.textContent = result?.message ?? "Nothing yet — take a screenshot";
    if (failed && alerted !== result.message) {
      alerted = result.message;
      onFailure(result, provider);
    }
  }

  async function refresh() {
    if (!card.isConnected) return;
    show(await invoke("get_ai_last_result"), state.provider);
    setTimeout(refresh, POLL_MS);
  }

  show(state.last_result, state.provider);
  setTimeout(refresh, POLL_MS);
  return card;
}
