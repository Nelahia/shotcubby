import { el, invoke } from "./shared.js";

/** Settings line for opening ShotCubby when the Windows session opens. */
export async function createLaunchRow() {
  const row = el("label", "row");
  const box = document.createElement("input");
  box.type = "checkbox";
  box.checked = await invoke("get_launch_at_login");
  box.addEventListener("change", async () => {
    try {
      await invoke("set_launch_at_login", { enabled: box.checked });
    } catch (err) {
      box.checked = !box.checked;
      console.error(err);
      window.alert(String(err));
    }
  });
  row.append(el("span", "label", "Open ShotCubby at session start"), box);
  return row;
}
