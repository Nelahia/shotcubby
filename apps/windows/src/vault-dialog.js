import { el, invoke } from "./shared.js";
import { t } from "./i18n.js";

function formatBytes(bytes) {
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} ${t("KB")}`;
  if (bytes < 1024 ** 3) return `${Math.round(bytes / 1024 ** 2)} ${t("MB")}`;
  return `${(bytes / 1024 ** 3).toFixed(1)} ${t("GB")}`;
}

export const describe = ({ count, bytes }) =>
  `${t(count === 1 ? "{count} screenshot" : "{count} screenshots", { count })} · ${formatBytes(bytes)}`;

function pathsBox(from, to) {
  const box = el("div", "dialog-paths");
  box.append(
    el("span", "status", t("From")), el("span", "mono", from),
    el("span", "status", t("To")), el("span", "mono strong", to),
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
      show(t("Moving your screenshots…"), t("This can take a moment for a large folder."), el("div", "dialog-bar"), actions());
      try {
        await invoke("move_vault", { target });
        show(t("Screenshots moved"), t("New captures are saved in the new folder."), pathsBox(info.path, target),
          actions(button(t("Done"), true, () => finish(true))));
      } catch (error) {
        show(t("Can't move"), String(error), actions(button(t("Close"), true, () => finish(false))));
      }
    }

    show(
      t("Move your screenshots?"),
      t("{summary}, dated folders included, will move to the new location. New captures will be saved there.", { summary: describe(info) }),
      pathsBox(info.path, target),
      actions(button(t("Cancel"), false, () => finish(false)), button(t("Move"), true, move)),
    );
  });
}
