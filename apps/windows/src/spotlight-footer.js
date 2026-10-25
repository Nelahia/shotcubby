import { el } from "./shared.js";
import { t } from "./i18n.js";

/**
 * The Spotlight footer: Copy/Preview shown inline as a legend, everything
 * else behind an "Actions" button that opens a small menu drawn above it.
 * Mirrors the Mac app's SpotlightFooter/SpotlightActionsMenu — one key cap
 * per shortcut combo instead of one cap per key.
 */
export function createSpotlightFooter(container, actions) {
  const primary = [
    { keys: "↩", label: t("Preview"), run: actions.preview },
    { keys: "Ctrl C", label: t("Copy"), run: actions.copy },
  ];
  const menuItems = [
    { keys: "Ctrl E", label: t("Rename"), run: actions.rename },
    { keys: "Ctrl R", label: t("Open Folder"), run: actions.reveal },
    { keys: "Ctrl ⌫", label: t("Move to Trash"), run: actions.trash, destructive: true },
    { keys: "Ctrl ,", label: t("Settings"), run: actions.settings, separatorBefore: true },
  ];

  let open = false;
  let highlighted = 0;

  const footerEl = el("div", "footer");
  const primaryEl = el("div", "footer-primary");
  const actionsBtn = el("button", "actions-btn");
  const menuEl = el("div", "actions-menu");
  menuEl.hidden = true;

  for (const item of primary) {
    const hint = el("button", "hint");
    hint.appendChild(el("span", "kbd", item.keys));
    hint.appendChild(el("span", "", item.label));
    hint.addEventListener("click", item.run);
    primaryEl.appendChild(hint);
  }

  actionsBtn.appendChild(el("span", "actions-label", t("Actions")));
  actionsBtn.appendChild(el("span", "kbd", "Ctrl K"));
  actionsBtn.addEventListener("click", toggle);

  footerEl.appendChild(primaryEl);
  footerEl.appendChild(el("div", "footer-spacer"));
  footerEl.appendChild(actionsBtn);
  container.appendChild(footerEl);
  container.appendChild(menuEl);

  function renderMenu() {
    menuEl.textContent = "";
    menuItems.forEach((item, index) => {
      if (item.separatorBefore) menuEl.appendChild(el("div", "actions-menu-sep"));
      const classes = ["actions-menu-item", item.destructive && "destructive", index === highlighted && "highlighted"]
        .filter(Boolean)
        .join(" ");
      const row = el("button", classes);
      row.appendChild(el("span", "", item.label));
      row.appendChild(el("span", "kbd", item.keys));
      row.addEventListener("mouseenter", () => {
        highlighted = index;
        renderMenu();
      });
      row.addEventListener("click", () => {
        close();
        item.run();
      });
      menuEl.appendChild(row);
    });
  }

  function toggle() {
    open ? close() : openMenu();
  }

  function openMenu() {
    open = true;
    highlighted = 0;
    menuEl.hidden = false;
    actionsBtn.classList.add("open");
    renderMenu();
  }

  function close() {
    open = false;
    menuEl.hidden = true;
    actionsBtn.classList.remove("open");
  }

  function moveHighlight(delta) {
    highlighted = Math.max(0, Math.min(menuItems.length - 1, highlighted + delta));
    renderMenu();
  }

  function runHighlighted() {
    const item = menuItems[highlighted];
    close();
    item.run();
  }

  return { toggle, close, isOpen: () => open, moveHighlight, runHighlighted };
}
