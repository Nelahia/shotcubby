import { listen } from "./shared.js";

/**
 * Calls `onChange` whenever the screenshot list changes behind the window's
 * back (a capture lands, AI naming renames one, one is removed), so an
 * already-open Spotlight never shows stale names. A rename passes its payload
 * `{ old_id, item }`, because a screenshot's id is its path and changes with it.
 */
export function watchScreenshotChanges(onChange) {
  listen("screenshot-added", () => onChange());
  listen("screenshot-removed", () => onChange());
  listen("screenshot-renamed", (event) => onChange(event.payload));
  listen("screenshots-reloaded", () => onChange());
}
