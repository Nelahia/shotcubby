import { listen, svgIcon, ICONS } from "./shared.js";
import { t } from "./i18n.js";

const pill = document.getElementById("pill");
pill.innerHTML = `${svgIcon(ICONS.check)}<span>${t("Copied")}</span>`;

listen("copy-toast-show", () => {
  pill.classList.remove("flash");
  void pill.offsetWidth; // restart the animation when copies happen back-to-back
  pill.classList.add("flash");
});
