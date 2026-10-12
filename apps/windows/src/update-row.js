import { el, invoke, appVersion } from "./shared.js";

const POLL_MS = 1000;

function statusText({ state, detail, checked_at: checkedAt }) {
  switch (state) {
    case "checking":
      return "Checking for updates…";
    case "installing":
      return `Installing ${detail}…`;
    case "up_to_date":
      return `Up to date · checked ${new Date(checkedAt).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })}`;
    case "error":
      return "Couldn't check for updates";
    default:
      return "Not checked yet";
  }
}

/** Settings line: running version, update status and a "Check now" button. */
export async function createUpdateRow() {
  const row = el("div", "row");
  const text = el("div", "label");
  const title = el("div", "", `ShotCubby ${await appVersion()}`);
  const status = el("div", "status");
  text.append(title, status);
  const button = el("button", "reset-btn", "Check now");
  row.append(text, button);

  async function show(current) {
    status.textContent = statusText(current);
    button.disabled = current.state === "checking" || current.state === "installing";
    if (button.disabled) setTimeout(refresh, POLL_MS);
  }

  async function refresh() {
    show(await invoke("get_update_status"));
  }

  button.addEventListener("click", async () => {
    button.disabled = true;
    status.textContent = statusText({ state: "checking" });
    show(await invoke("check_for_updates"));
  });

  await refresh();
  return row;
}
