import { el, invoke } from "./shared.js";

/** Settings line to pick the provider; `onChange(provider, hasKey)` re-targets the key block. */
export function createAiProviderRow(state, onChange) {
  const row = el("div", "row");
  const segmented = el("div", "seg");
  segmented.setAttribute("role", "group");
  segmented.setAttribute("aria-label", "Provider");

  const buttons = state.providers.map(({ id, label }) => {
    const button = el("button", "", label.split(" (")[0]);
    button.addEventListener("click", async () => {
      const hasKey = await invoke("set_ai_rename_provider", { provider: id });
      select(id);
      onChange(id, hasKey);
    });
    return { id, button };
  });

  function select(provider) {
    buttons.forEach(({ id, button }) => button.setAttribute("aria-pressed", String(id === provider)));
  }

  segmented.append(...buttons.map(({ button }) => button));
  select(state.provider);
  row.append(el("div", "label", "Provider"), segmented);
  return row;
}
