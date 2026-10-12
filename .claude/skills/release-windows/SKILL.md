---
name: release-windows
description: Publish a ShotCubby release rebuilding ONLY the Windows app (CI runs the Windows job alone; the macOS disk image is carried over from the previous release). Use when the user runs /release-windows.
disable-model-invocation: true
argument-hint: "[version, e.g. 2.3.0 — default: next patch]"
---

Run a Windows-only ShotCubby release. The user typing `/release-windows` is the
authorization to publish; do not ask again unless something below blocks.

1. **Check the repo** (`git status -sb`, `git fetch`):
   - Uncommitted changes → stop, list them, ask whether to commit them first. Never release uncommitted work.
   - Local commits not on `origin/main` → `git push origin main` first (the CI builds the pushed commit).
2. **Pick the tag**: if the user gave a version use `v<version>`; otherwise the latest
   `vX.Y.Z` tag (`git tag --sort=-v:refname | head -1`) with the patch number + 1.
   Refuse a tag that already exists.
3. **Start the CI, Windows only**:
   `gh workflow run release.yml -f tag=<tag> -f platform=windows`
   then find the run: `gh run list --workflow release.yml --limit 1`. Only the Windows
   job runs; the release job copies `ShotCubby.dmg` over from the previous release so
   the "latest" download link keeps working. The Mac app is NOT rebuilt. Installed
   Windows apps pick the new version up through `latest.json` (they check at launch and
   every 6 hours; Settings → "Check now" does it at once).
4. **Wait in the background** — `gh run watch <id> --exit-status` with
   `run_in_background: true`; never block the conversation on it. Tell the user the
   run is going (~6 min) and carry on with any other request.
5. **When it ends**, check `gh run view <id> --json jobs` and
   `gh release view <tag> --json assets`. Success = release published with new
   `ShotCubby-Setup.exe`, `ShotCubby.msi`, `latest.json` plus the carried-over `ShotCubby.dmg`.
   On failure read the failing job's log (`gh api repos/Nelahia/shotcubby/actions/jobs/<job-id>/logs`),
   report the cause; do not retry blindly.
6. Report in French: tag, what was published, any failure.
