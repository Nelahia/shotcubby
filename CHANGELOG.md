# Changelog

What changed in each release, and why. The newest version is first. Fixes are
kept here with their cause so the same problem is not fixed twice.

Versions are the tags of this repository; both apps (macOS and Windows) are
released together unless a note says otherwise.

Every version has its own entry, written before the tag is created: one short,
precise bullet per change the user can see, and for a fix the symptom and its
cause. The full rules are in [CLAUDE.md](CLAUDE.md).

## 2.2.33 — 2026-10-25

### Fixed
- **Windows: the whole app froze** (tray, windows and every shortcut dead until
  it was killed). The shortcut plugin holds its lock while it runs a shortcut,
  and the region-capture shortcut opened the Snipping Tool from there. Opening
  it waits by dispatching window messages, so a second shortcut pressed in the
  meantime asked for the lock the same thread already held. The two capture
  shortcuts now leave the handler at once and run on their own thread.

## 2.2.32 — 2026-10-24

### Fixed
- **AI naming skipped some screenshots.** Haiku 5.5 thinks by default, and
  thinking is paid out of `max_tokens`: on a busy screenshot all 300 tokens went
  to reasoning and the answer had no text. Thinking is now off for the title
  request and the ceiling is 1024. OpenAI's ceiling is 1024 too, an empty answer
  counts as no title, and Settings shows why it failed.
- **Windows: a manual rename sometimes did nothing.** A fresh capture can still
  be held by Defender, the indexer or the app that took it. The rename is
  retried, and a failure is shown instead of leaving the row stuck.
- **Two selected rows, arrows stuck.** Two clipboard captures taken in the same
  second shared one file name: the second overwrote the first and the list got
  two entries with the same id. Names are now unique. (macOS and Windows)

## 2.2.29 – 2.2.31 — 2026-10-16

### Added
- **AI naming**: rename screenshots with your own Anthropic or OpenAI key.
  Nothing is sent anywhere until you turn it on and save a key.
- New Settings look, with the real logo colors in the sidebar.

### Changed
- OpenAI naming uses `gpt-5-nano`, the price equivalent of Haiku.

## 2.2.21 – 2.2.28 — 2026-10-12

### Added
- Screenshots live in `Documents\ShotCubby`, and the folder can be moved.
- Past days are filed into `YYYY-MM-DD` folders (Settings → File past days).
- Settings sidebar with General, Screenshots and Shortcuts on both platforms.
- macOS: in-app updates with Sparkle and a Check for Updates button; ShotCubby
  also sits in the Dock and a click opens the search.
- Windows: only one copy runs; launching it again opens the search.
- Windows: every shortcut, capture ones included, can be rebound.

### Changed
- The repository is split into `apps/macos` and `apps/windows`.
- Releases are started on an existing tag, and each platform publishes on its
  own.

### Fixed
- macOS: the Spotlight closed right after opening, and Esc did not reach the
  popover.
- macOS: ShotCubby swallowed paste in other apps.
- Windows: Quit now really quits, and dev builds no longer update themselves.

## Before 2.2.21

See the [commit history](https://github.com/Nelahia/shotcubby/commits/main) and
the [releases](https://github.com/Nelahia/shotcubby/releases).
