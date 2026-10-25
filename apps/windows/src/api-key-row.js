import { el, invoke, svgIcon, ICONS } from "./shared.js";
import { t } from "./i18n.js";

const asFailure = (err) => (typeof err === "string" ? { kind: "other", message: err } : err);

/**
 * Settings block for the provider's API key. The key goes straight to the
 * Windows Credential Manager and is never shown again. `block.show(provider,
 * hasKey)` re-targets it when the provider changes; `onFailure(failure,
 * provider)` and `onSuccess()` let the page explain a failed test.
 */
export function createApiKeyRow(state, { onFailure, onSuccess }) {
  const block = el("div", "key-block");
  const input = document.createElement("input");
  input.type = "password";
  input.className = "field";
  input.autocomplete = "off";
  const save = el("button", "reset-btn", t("Save"));
  const test = el("button", "reset-btn", t("Test"));

  const chip = el("span", "key-chip");
  const remove = el("button", "key-chip-x");
  remove.title = t("Remove the saved key");
  remove.setAttribute("aria-label", t("Remove the saved key"));
  remove.innerHTML = svgIcon(ICONS.close);
  remove.firstChild.setAttribute("width", "10");
  chip.append(t("✓ Key saved"), remove);

  const head = el("div", "key-head");
  head.append(t("API key"), el("span", "spacer"), chip);
  const fields = el("div", "key-fields");
  fields.append(input, save, test);
  const note = el("div", "key-note");
  block.append(head, fields, note);

  let provider = state.provider;

  /** `tone`: "ok" or "bad" colors the line so a result is never missed. */
  function say(message, tone) {
    note.innerHTML = svgIcon(ICONS.lock);
    note.append(message);
    note.classList.toggle("ok", tone === "ok");
    note.classList.toggle("bad", tone === "bad");
  }

  function show(next, hasKey, message, tone) {
    provider = next;
    input.value = "";
    input.placeholder = hasKey ? t("Paste a new key to replace it") : t("Paste your API key");
    test.hidden = chip.hidden = !hasKey;
    say(message ?? t("Stored in the Windows Credential Manager. It only leaves this PC to call your provider."), tone);
  }

  function setBusy(busy) {
    [save, test, remove].forEach((button) => (button.disabled = busy));
  }

  async function run(busyText, action) {
    setBusy(true);
    say(busyText);
    try {
      await action();
    } finally {
      setBusy(false);
    }
  }

  save.addEventListener("click", () =>
    run(t("Saving…"), async () => {
      try {
        await invoke("save_api_key", { provider, key: input.value });
        onSuccess();
        show(provider, true, t("Key saved. Press Test to check it works."), "ok");
      } catch (err) {
        say(String(err), "bad");
      }
    }),
  );

  test.addEventListener("click", () =>
    run(t("Testing the key with the provider…"), async () => {
      try {
        await invoke("test_api_key", { provider });
        onSuccess();
        say(t("The key works. New screenshots will be renamed."), "ok");
      } catch (err) {
        const failure = asFailure(err);
        say(failure.message, "bad");
        onFailure(failure, provider);
      }
    }),
  );

  remove.addEventListener("click", () =>
    run(t("Removing…"), async () => {
      await invoke("delete_api_key", { provider });
      onSuccess();
      show(provider, false, t("Key removed."), "ok");
    }),
  );

  show(state.provider, state.has_key);
  block.show = show;
  return block;
}
