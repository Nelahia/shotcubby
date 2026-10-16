import { el, svgIcon, ICONS, openUrl } from "./shared.js";

const CONSOLES = {
  anthropic: { name: "Claude Console", keys: "https://platform.claude.com/settings/keys", billing: "https://platform.claude.com/settings/billing" },
  openai: { name: "OpenAI platform", keys: "https://platform.openai.com/api-keys", billing: "https://platform.openai.com/settings/organization/billing" },
};

const bold = (text) => el("strong", "", text);

/** What each kind of failure means to the user, and what to do about it. */
function describe(kind, provider, message) {
  const console_ = CONSOLES[provider] ?? CONSOLES.anthropic;
  switch (kind) {
    case "workspace":
      return {
        title: "This key isn’t tied to a workspace",
        body: ["Anthropic only accepts API keys created ", bold("inside a workspace"), ". The key you pasted works at the account level, so every request is refused."],
        steps: [
          ["Open the ", bold("API keys"), " page of the Claude Console."],
          ["Create a key and pick a workspace (the ", bold("Default"), " one is fine)."],
          ["Paste the new key below and press ", bold("Test"), "."],
        ],
        action: { label: "Open Claude Console", url: console_.keys },
      };
    case "rejected":
      return {
        title: "The provider refused this key",
        body: ["The key is wrong, was revoked, or was copied incompletely. Paste it again, or create a new one."],
        action: { label: `Open ${console_.name}`, url: console_.keys },
      };
    case "credit":
      return {
        title: "No credit left on this account",
        body: ["API usage is billed separately from a Claude or ChatGPT subscription. Add credit, then try again. A screenshot costs a fraction of a cent."],
        action: { label: "Open billing", url: console_.billing },
      };
    case "rate_limit":
      return { title: "Too many requests", body: ["The provider is limiting this key for a moment. AI naming will work again shortly."] };
    case "network":
      return { title: "Can’t reach the provider", body: ["Check your internet connection. Screenshots keep their current names until it is back."] };
    default:
      return { title: "AI naming didn’t work", body: [message] };
  }
}

/** A dismissible alert card; `show(failure, provider)` explains a failure, `hide()` clears it. */
export function createAiAlert() {
  const alert = el("section", "alert");
  alert.setAttribute("role", "alert");
  alert.hidden = true;

  function show({ kind, message }, provider) {
    const info = describe(kind, provider, message);
    const icon = el("span", "alert-icon");
    icon.innerHTML = svgIcon(ICONS.alert);
    const text = el("div");
    text.append(el("div", "alert-title", info.title));
    const body = el("p", "alert-body");
    body.append(...info.body);
    text.append(body);
    const head = el("div", "alert-head");
    head.append(icon, text);

    const parts = [head];
    if (info.steps) {
      const steps = el("ol", "alert-steps");
      info.steps.forEach((step) => {
        const item = el("li");
        item.append(...step);
        steps.append(item);
      });
      parts.push(steps);
    }

    const actions = el("div", "alert-actions");
    if (info.action) {
      const open = el("button", "alert-btn", info.action.label);
      open.insertAdjacentHTML("beforeend", svgIcon(ICONS.external));
      open.addEventListener("click", () => openUrl(info.action.url));
      actions.append(open);
    }
    const dismiss = el("button", "alert-dismiss", "Dismiss");
    dismiss.addEventListener("click", hide);
    actions.append(dismiss);
    parts.push(actions);

    alert.replaceChildren(...parts);
    alert.hidden = false;
  }

  function hide() {
    alert.hidden = true;
  }

  alert.show = show;
  alert.hide = hide;
  return alert;
}
