---
name: release-mac
description: Publish a ShotCubby release rebuilding ONLY the macOS app (CI runs the Mac job alone; the Windows files are carried over from the previous release). Use when the user runs /release-mac.
disable-model-invocation: true
argument-hint: "[version, e.g. 2.3.0 — default: next patch]"
---

Run a macOS-only ShotCubby release. The user typing `/release-mac` is the
authorization to publish; do not ask again unless something below blocks.

1. **Check the repo** (`git status -sb`, `git fetch`):
   - Uncommitted changes → stop, list them, ask whether to commit them first. Never release uncommitted work.
   - Local commits not on `origin/main` → `git push origin main` first (the CI builds the pushed commit).
2. **Pick the tag**: if the user gave a version use `v<version>`; otherwise the latest
   `vX.Y.Z` tag (`git tag --sort=-v:refname | head -1`) with the patch number + 1.
   Refuse a tag that already exists.
3. **Start the CI, macOS only**:
   `gh workflow run release.yml -f tag=<tag> -f platform=mac`
   then find the run: `gh run list --workflow release.yml --limit 1`. Only the Mac job
   runs; the release job copies the Windows installers and `latest.json` over from the
   previous release so the "latest" download links keep working. The Windows app is NOT
   rebuilt and its in-app updater sees no new version.
4. **Wait in the background** — `gh run watch <id> --exit-status` with
   `run_in_background: true`; never block the conversation on it. Tell the user the
   run is going (~3 min) and carry on with any other request.
5. **When it ends**, check `gh run view <id> --json jobs` and
   `gh release view <tag> --json assets`. Success = release published with a new
   `ShotCubby.dmg` plus the carried-over `ShotCubby-Setup.exe`, `ShotCubby.msi`, `latest.json`.
   On failure read the failing job's log (`gh api repos/Nelahia/shotcubby/actions/jobs/<job-id>/logs`),
   report the cause; do not retry blindly. The Swift code cannot be compiled locally on
   Windows, so a compile error only shows up here — fix it, push, then rerun.
6. Report in French: tag, what was published, any failure.
