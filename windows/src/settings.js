import { invoke } from "./shared.js";

const field = document.getElementById("hotkey-field");
const resetBtn = document.getElementById("reset-btn");
const errorEl = document.getElementById("error");

let recording = false;
let currentDisplay = "";

async function load() {
  const hotkey = await invoke("get_hotkey");
  currentDisplay = hotkey.display;
  field.textContent = currentDisplay;
}

function startRecording() {
  recording = true;
  errorEl.textContent = "";
  field.textContent = "Press a key combination…";
  field.classList.add("recording");
}

function stopRecording() {
  recording = false;
  field.classList.remove("recording");
}

field.addEventListener("click", () => {
  if (!recording) startRecording();
});

document.addEventListener("keydown", async (e) => {
  if (!recording) return;
  e.preventDefault();

  const hasModifier = e.ctrlKey || e.altKey || e.shiftKey || e.metaKey;
  const isModifierKey = ["Control", "Alt", "Shift", "Meta"].some((m) => e.code.startsWith(m));

  if (e.code === "Escape" && !hasModifier) {
    stopRecording();
    field.textContent = currentDisplay;
    return;
  }
  if (isModifierKey) return; // wait for the actual key
  if (!hasModifier) return; // at least one modifier required — plain typing can't be bound

  const mods = [];
  if (e.ctrlKey) mods.push("Ctrl");
  if (e.altKey) mods.push("Alt");
  if (e.shiftKey) mods.push("Shift");
  if (e.metaKey) mods.push("Super");
  const combo = [...mods, e.code].join("+");

  stopRecording();
  try {
    currentDisplay = await invoke("set_hotkey", { hotkeyStr: combo });
    field.textContent = currentDisplay;
  } catch (err) {
    errorEl.textContent = String(err);
    field.textContent = currentDisplay;
  }
});

resetBtn.addEventListener("click", async () => {
  const result = await invoke("reset_hotkey");
  currentDisplay = result.display;
  field.textContent = currentDisplay;
});

load();
