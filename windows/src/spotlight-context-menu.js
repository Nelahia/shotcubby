import { el } from "./shared.js";

/**
 * Right-click menu for a result row: same look as the footer's Actions
 * menu (reuses its CSS classes) but anchored at the cursor via `show(x, y)`
 * instead of pinned to the footer corner. Mouse-only — no keyboard nav.
 */
export function createContextMenu(container, itemActions) {
  const menuEl = el("div", "actions-menu context");
  menuEl.hidden = true;
  container.appendChild(menuEl);

  let open = false;

  function renderMenu() {
    menuEl.textContent = "";
    for (const item of itemActions) {
      const classes = ["actions-menu-item", item.destructive && "destructive"].filter(Boolean).join(" ");
      const row = el("button", classes);
      row.appendChild(el("span", "", item.label));
      row.appendChild(el("span", "kbd", item.keys));
      row.addEventListener("click", () => {
        hide();
        item.run();
      });
      menuEl.appendChild(row);
    }
  }

  function onDocClick(e) {
    if (!menuEl.contains(e.target)) hide();
  }

  function onKeydown(e) {
    if (e.key === "Escape") hide();
  }

  function show(x, y) {
    renderMenu();
    menuEl.hidden = false;
    menuEl.style.left = "0px";
    menuEl.style.top = "0px";
    open = true;

    const width = menuEl.offsetWidth || 248;
    const height = menuEl.offsetHeight;
    const left = Math.max(8, Math.min(x, window.innerWidth - width - 8));
    const top = Math.max(8, Math.min(y, window.innerHeight - height - 8));
    menuEl.style.left = `${left}px`;
    menuEl.style.top = `${top}px`;

    document.addEventListener("click", onDocClick);
    document.addEventListener("keydown", onKeydown);
  }

  function hide() {
    if (!open) return;
    open = false;
    menuEl.hidden = true;
    document.removeEventListener("click", onDocClick);
    document.removeEventListener("keydown", onKeydown);
  }

  return { show, hide, isOpen: () => open };
}
