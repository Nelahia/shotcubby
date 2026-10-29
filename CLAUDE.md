# ShotCubby

Two independent native apps, no shared code: `apps/macos` (Swift) and
`apps/windows` (Tauri, Rust + plain JS). Each has its own README with build steps.

## Changelog (mandatory for every version)

Every released version gets its own entry in [`CHANGELOG.md`](CHANGELOG.md),
written **before** the tag is created and committed with the release.

- One entry per version, newest first, headed `## X.Y.Z — YYYY-MM-DD`. Never
  group several versions in one entry.
- Sections, only the ones that apply: **Added**, **Changed**, **Fixed**,
  **Removed**.
- One bullet per change, written for the user: short, precise, no filler
  ("various improvements" is not an entry). Name the platform when a change
  only concerns one.
- A fix states the symptom the user saw and its cause, so it is not fixed twice.
- Leave out what the user cannot see (refactors, CI, commit hashes), unless it
  changes how the app is built, installed or updated.
- If a version changes nothing visible, say so in one line rather than skip it.

The `/release`, `/release-mac` and `/release-windows` skills stop when the
version has no entry.

## Dragging a screenshot out (both apps)

Press a screenshot and move a few pixels: the file is dragged out as a **copy**
(never a move, the original stays in the ShotCubby folder). What cost a release
each time, so it is not found twice:

- **Windows, preview:** the drag picture is drawn by the window under the cursor.
  The search and the popover are built with `disable_drag_drop_handler()`; with
  Tauri's own drop target on, the picture is missing over them. Keep it off, and
  keep `dragover`/`drop` blocked in `src/file-drag.js`, or the webview opens a
  dropped file in place of the page.
- **Windows, closing:** both windows close on blur, so `file_drag::is_dragging()`
  holds that off during the drag. The window closes after a drop elsewhere; Esc,
  or a drop back on the window itself, cancels and keeps it open.
- **macOS, window:** the search panel must not be `isMovableByWindowBackground`:
  it wins over the file drag and carries the whole panel. It moves by its search
  bar only (`WindowDragArea`). The panel never becomes the active app, so it
  stays open after a drop, which is wanted.
- **macOS, copy:** the file is offered with `registerFileRepresentation`, not as
  its own path, which Finder would move on the same disk.
- A drag can only be checked by hand with a real mouse (CI compiles it, nothing
  more): drag from the search and from the popover to the desktop, a chat,
  then back onto the window.

## Design reference

The look of both apps (navy palette, popover, search, Settings; dark and light)
is kept in [`docs/design/`](docs/design/README.md). Change the app's look, change
those files in the same PR, and replace them rather than adding copies.
