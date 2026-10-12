#!/usr/bin/env bash
# Makes sure the GitHub release for a tag exists, so a platform's publish job
# can upload into it no matter which platform finishes first.
#
#   ensure-release.sh <tag> <platform> <commit-sha>
#
# <platform> is what this run rebuilds: both, mac or windows. When the release
# has to be created, it is first seeded with the previous version's files, so a
# one-platform build still carries the other platform's installers. Needs GH_TOKEN.
#
# The release is created WITHOUT the Latest flag: what the landing page and the
# in-app updates serve is the "live" release, moved only by ShotCubby Releases
# (github.com/Nelahia/shotcubby-releases). A build never reaches users by itself.
set -euo pipefail

tag="$1"
platform="$2"
sha="$3"
app="ShotCubby"

if gh release view "$tag" >/dev/null 2>&1; then
  exit 0
fi

mkdir -p seed
# The highest version below this tag. Not "latest": that is the live release,
# which may hold an older version's files.
previous="$(gh release list --limit 100 --json tagName --jq '.[].tagName' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | { cat; echo "$tag"; } | sort -Vu \
  | grep -x -B1 "$tag" | head -1 || true)"
if [ -n "$previous" ] && [ "$previous" != "$tag" ]; then
  gh release download "$previous" --dir seed \
    --pattern "$app.dmg" --pattern "$app.dmg.sha256" --pattern "$app-Setup.exe" --pattern "$app.msi" \
    --pattern latest.json --pattern appcast.xml \
    || echo "Nothing to carry over from $previous."
else
  echo "No previous release to carry files over from."
fi

note=""
case "$platform" in
  mac)
    windows_version="$(jq -r '.version // "unknown"' seed/latest.json 2>/dev/null || echo unknown)"
    note="_Only the macOS app was rebuilt for this release; the Windows installers are the previous release's, unchanged (version $windows_version)._" ;;
  windows)
    note="_Only the Windows app was rebuilt for this release; the macOS disk image is the previous release's, unchanged._" ;;
esac

cat > notes.md <<EOF
## $app $tag

$note

Menu bar app that automatically captures and organizes all your screenshots.

### macOS
Signed with a Developer ID Application certificate and notarized by Apple —
opens with no Gatekeeper warning.

Download \`$app.dmg\`, open it, drag \`$app.app\` to Applications.
Requires macOS 14.0 (Sonoma) or later. The disk image's SHA256 is in \`$app.dmg.sha256\`.

### Windows
If Windows SmartScreen warns on first run, click "More info" → "Run anyway".
Signed builds use a free certificate from the SignPath Foundation; a new
certificate can still trigger the warning until it builds reputation.

Download \`$app-Setup.exe\` (or \`$app.msi\`). Requires Windows 10/11.
EOF

seeded=()
for file in seed/*; do
  [ -e "$file" ] && seeded+=("$file")
done

gh release create "$tag" "${seeded[@]}" \
  --target "$sha" --title "$tag" --notes-file notes.md --generate-notes --latest=false
