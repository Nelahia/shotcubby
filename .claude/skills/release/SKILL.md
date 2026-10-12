---
name: release
description: Publish a ShotCubby release for BOTH macOS and Windows (CI builds and publishes both apps). Use when the user runs /release.
disable-model-invocation: true
argument-hint: "[version, e.g. 2.3.0 — default: next patch]"
---

Run a full ShotCubby release (macOS + Windows). The user typing `/release` is the
authorization to publish; do not ask again unless something below blocks.

1. **Check the repo** (`git status -sb`, `git fetch`):
   - Uncommitted changes → stop, list them, ask whether to commit them first. Never release uncommitted work.
   - Local commits not on `origin/main` → `git push origin main` first (the CI builds the pushed commit).
2. **Pick the tag**: if the user gave a version use `v<version>`; otherwise the latest
   `vX.Y.Z` tag (`git tag --sort=-v:refname | head -1`) with the patch number + 1.
   Refuse a tag that already exists.
3. **Start the CI** (both platforms; each one publishes its files into the release as soon
   as its own build is done, in parallel — a failure on one side never blocks the other):
   `gh workflow run release.yml -f tag=<tag> -f platform=both`
   then find the run: `gh run list --workflow release.yml --limit 1`.
4. **Wait in the background** — `gh run watch <id> --exit-status` with
   `run_in_background: true`; never block the conversation on it. Tell the user the
   run is going (builds take ~6 min) and carry on with any other request.
5. **When it ends**, check `gh run view <id> --json jobs` and
   `gh release view <tag> --json assets`. Success = release published with
   `ShotCubby.dmg`, `ShotCubby-Setup.exe`, `ShotCubby.msi`, `latest.json`.
   On failure read the failing job's log (`gh api repos/Nelahia/shotcubby/actions/jobs/<job-id>/logs`),
   report the cause; do not retry blindly.
6. Report in French: tag, what was published, any failure. Mention that the Windows app
   updates itself from `latest.json`.
