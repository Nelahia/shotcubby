import { invoke, el } from "./shared.js";
import { t } from "./i18n.js";

/**
 * The popover's folder-access-failure card, shown instead of the filter bar
 * when the watched folder can't be read. `paths` is `{ screenshotDir,
 * vaultDir }`; `onChanged` is called after a folder pick or a retry so the
 * caller can refresh its own state.
 */
export function renderAccessCard(container, failure, paths, onChanged) {
  container.innerHTML = "";

  const tag = el("div", "tag");
  tag.appendChild(el("span", "dot"));
  tag.appendChild(el("span", "", t("Clipboard captures only")));
  container.appendChild(tag);

  const isMissing = failure === "missing";
  const title = el("h3", "", isMissing ? t("That screenshot folder is gone") : t("Windows is blocking ShotCubby from this folder"));
  const explanation = el(
    "p",
    "",
    isMissing
      ? t("ShotCubby can't find the folder it was watching. Pick the folder your screenshots actually go to.")
      : t("Controlled Folder Access (or similar protection) is stopping ShotCubby from moving screenshots out of this folder.")
  );
  container.appendChild(title);
  container.appendChild(explanation);

  const pathRow = el("div", "path-row");
  pathRow.appendChild(el("span", "", paths.screenshotDir));
  pathRow.appendChild(el("span", "", "→"));
  pathRow.appendChild(el("span", "", paths.vaultDir));
  container.appendChild(pathRow);

  const chooseFolder = async () => {
    const folder = await invoke("choose_custom_folder");
    if (folder) await onChanged();
  };
  const retryAccess = async () => {
    await invoke("retry_screenshot_access");
    await onChanged();
  };

  if (isMissing) {
    container.appendChild(primaryButton(t("Choose Folder…"), chooseFolder));
  } else {
    container.appendChild(primaryButton(t("Open Windows Security"), () => invoke("open_windows_security")));
    container.appendChild(linkButton(t("Recheck access"), retryAccess));
    container.appendChild(linkButton(t("Use a different folder…"), chooseFolder, true));
  }
}

function primaryButton(label, onClick) {
  const btn = el("button", "primary-btn", label);
  btn.addEventListener("click", onClick);
  return btn;
}

function linkButton(label, onClick, muted) {
  const btn = el("button", muted ? "muted-btn" : "link-btn", label);
  btn.addEventListener("click", onClick);
  return btn;
}
