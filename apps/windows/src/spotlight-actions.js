import { invoke, currentWindow } from "./shared.js";

/**
 * The four actions a selected result can trigger, each closing the panel
 * afterward except delete (which just drops the row). `getSelected` reads
 * the caller's current selection; `onDeleted` lets the caller update its
 * own list/selection state after a successful delete. Copy closes the panel
 * at once and leaves the confirmation to the separate copy toast window.
 */
export function createSpotlightActions({ getSelected, onDeleted }) {
  async function copySelected() {
    const shot = getSelected();
    if (!shot) return;
    await invoke("copy_screenshot", { path: shot.path });
    await currentWindow().hide();
    invoke("show_copy_toast");
  }

  async function previewSelected() {
    const shot = getSelected();
    if (!shot) return;
    await invoke("open_screenshot", { path: shot.path });
    await currentWindow().hide();
  }

  async function revealSelected() {
    const shot = getSelected();
    if (!shot) return;
    await invoke("reveal_screenshot", { path: shot.path });
    await currentWindow().hide();
  }

  async function deleteSelected() {
    const shot = getSelected();
    if (!shot) return;
    await invoke("delete_screenshot", { id: shot.id });
    onDeleted(shot);
  }

  return { copySelected, previewSelected, revealSelected, deleteSelected };
}
