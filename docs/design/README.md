# Design

`navy/` holds the sources of the **ShotCubby palette navy** canvas (Claude Design):
the palette and its roles, the tray popover, the search panel and the macOS
Settings window, each in dark and in light. It is the reference for both apps'
colors and layout. `canvas.json` is the index, each `*.dc.html` one artboard.

- Dark is the default look of the boards; `Light.dc.html` shows the same three
  windows in light mode (the `mode` prop of each board).
- The files only render inside Claude Design (they load its `support.js`). The
  canvas itself: https://claude.ai/artifact/GfFm6SowokLotcJN7XFS99 (private).
- Kept in sync with the released app: the Settings board is at version 2.4.4
  (own title bar with Minimize and Close, larger steel-blue logo tile, the
  Appearance, session start and Dock rows).
- Replace the files when the look changes; do not keep old copies, git has them.
