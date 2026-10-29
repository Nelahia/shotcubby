import { invoke } from "./shared.js";

/** How far the pointer must travel, held down, before a click turns into a drag. */
const DRAG_DISTANCE = 6;

/**
 * Lets `element` be dragged out of the window as the screenshot's real file
 * (onto the desktop, Explorer, a chat, a mail…). The native drag starts once
 * the pointer moved a few pixels while pressed; a plain click is untouched.
 */
export function enableFileDrag(element, shot) {
  // The browser's own image drag would take over the pointer otherwise.
  element.addEventListener("dragstart", (e) => e.preventDefault());
  element.addEventListener("pointerdown", (down) => {
    if (down.button !== 0 || down.target.closest("input, button")) return;
    const stop = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", stop);
      window.removeEventListener("pointercancel", stop);
    };
    const move = (e) => {
      if (Math.hypot(e.clientX - down.clientX, e.clientY - down.clientY) < DRAG_DISTANCE) return;
      stop();
      invoke("start_file_drag", { path: shot.path }).catch(console.error);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", stop);
    window.addEventListener("pointercancel", stop);
  });
}
