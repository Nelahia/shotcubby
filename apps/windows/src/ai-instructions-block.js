import { el, invoke } from "./shared.js";

const MAX = 500;
const SAVE_DELAY_MS = 500;
const SAVED_SHOWN_MS = 1500;

/** Free-text naming convention sent to the model with every screenshot; saved as you type. */
export function createAiInstructionsBlock(state) {
  const block = el("div", "key-block");
  const counter = el("span", "key-note");
  const head = el("div", "key-head");
  head.append("Naming instructions", el("span", "key-note", "Optional"), el("span", "spacer"), counter);

  const area = document.createElement("textarea");
  area.className = "field area";
  area.maxLength = MAX;
  area.placeholder = "e.g. lowercase kebab-case, start with the app name, in English";
  area.value = state.instructions;

  block.append(
    head,
    area,
    el(
      "div",
      "key-note",
      "Tell the AI how you want screenshots named. These instructions win over its defaults: length, language, format, a date prefix…",
    ),
  );

  let timer;
  function showCount(saved) {
    counter.textContent = saved ? "Saved" : `${area.value.length}/${MAX}`;
    counter.classList.toggle("ok", !!saved);
  }

  async function save() {
    await invoke("set_ai_rename_instructions", { instructions: area.value });
    showCount(true);
    setTimeout(() => showCount(false), SAVED_SHOWN_MS);
  }

  area.addEventListener("input", () => {
    showCount(false);
    clearTimeout(timer);
    timer = setTimeout(save, SAVE_DELAY_MS);
  });

  showCount(false);
  return block;
}
