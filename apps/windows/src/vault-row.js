import { el, invoke, svgIcon, ICONS } from "./shared.js";
import { describe, openMoveDialog } from "./vault-dialog.js";

/** Settings block showing where the screenshots live, with a button to move them. */
export async function createVaultRow() {
  const block = el("div", "vault");
  const card = el("div", "vault-card");
  const icon = el("span", "vault-icon");
  icon.innerHTML = svgIcon(ICONS.folder);
  const text = el("div", "label");
  const path = el("div", "mono vault-path");
  const summary = el("div", "status");
  text.append(path, summary);
  const open = el("button", "reset-btn", "Open");
  const move = el("button", "dialog-go", "Move…");
  card.append(icon, text, open, move);
  block.append(
    el("div", "vault-title", "Screenshots folder"),
    card,
    el("div", "status", "Pick a new location and ShotCubby moves your existing screenshots there, then saves new ones in it."),
  );

  let info;
  async function render() {
    info = await invoke("get_vault_info");
    path.textContent = info.path;
    summary.textContent = describe(info);
  }

  open.addEventListener("click", () => invoke("open_vault_folder"));
  move.addEventListener("click", async () => {
    const target = await invoke("choose_vault_folder");
    if (target && (await openMoveDialog(info, target))) await render();
  });

  await render();
  return block;
}
