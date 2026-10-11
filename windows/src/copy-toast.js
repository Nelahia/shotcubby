import { listen, svgIcon, ICONS } from "./shared.js";

const pill = document.getElementById("pill");
pill.innerHTML = `${svgIcon(ICONS.check)}<span>Copied</span>`;

listen("copy-toast-show", () => {
  pill.classList.remove("flash");
  void pill.offsetWidth; // restart the animation when copies happen back-to-back
  pill.classList.add("flash");
});
