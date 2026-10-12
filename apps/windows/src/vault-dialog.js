import { el, invoke } from "./shared.js";

function formatBytes(bytes) {
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  if (bytes < 1024 ** 3) return `${Math.round(bytes / 1024 ** 2)} MB`;
  return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
}

export const describe = ({ count, bytes }) =>
  `${count} screenshot${count === 1 ? "" : "s"} · ${formatBytes(bytes)}`;

function pathsBox(from, to) {
  const box = el("div", "dialog-paths");
  box.append(
    el("span", "status", "From"), el("span", "mono", from),
    el("span", "status", "To"), el("span", "mono strong", to),
  );
  return box;
}

/**
 * Confirms, runs and reports a vault move in one modal. Resolves `true` once
 * the screenshots were moved, `false` if the user backed out or it failed.
 */
export function openMoveDialog(info, target) {
  return new Promise((resolve) => {
    const scrim = el("div", "dialog-scrim");
    const card = el("div", "dialog");
    scrim.append(card);
    document.body.append(scrim);

    const finish = (moved) => {
      scrim.remove();
      resolve(moved);
    };
    const button = (label, primary, onClick) => {
      const node = el("button", primary ? "dialog-go" : "reset-btn", label);
      node.addEventListener("click", onClick);
      return node;
    };
    const show = (title, text, ...extra) => {
      const actions = extra.pop();
      card.replaceChildren(el("div", "dialog-title", title), el("div", "status", text), ...extra, actions);
    };
    const actions = (...buttons) => {
      const row = el("div", "dialog-actions");
      row.append(...buttons);
      return row;
    };

    async function move() {
      show("Moving your screenshots…", "This can take a moment for a large folder.", el("div", "dialog-bar"), actions());
      try {
        await invoke("move_vault", { target });
        show("Screenshots moved", "New captures are saved in the new folder.", pathsBox(info.path, target),
          actions(button("Done", true, () => finish(true))));
      } catch (error) {
        show("Can't move", String(error), actions(button("Close", true, () => finish(false))));
      }
    }

    show(
      "Move your screenshots?",
      `${describe(info)}, dated folders included, will move to the new location. New captures will be saved there.`,
      pathsBox(info.path, target),
      actions(button("Cancel", false, () => finish(false)), button("Move", true, move)),
    );
  });
}
