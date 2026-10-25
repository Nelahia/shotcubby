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
