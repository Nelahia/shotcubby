#!/usr/bin/env bash
# Makes sure the GitHub release for a tag exists, so a platform's publish job
# can upload into it no matter which platform finishes first.
#
#   ensure-release.sh <tag> <platform> <commit-sha>
#
# <platform> is what this run rebuilds: both, mac or windows. When the release
# has to be created, it is first seeded with the previous release's files so
# the "latest" download links and the Windows updater manifest keep working
# until the other platform publishes its own. Needs GH_TOKEN.
set -euo pipefail

tag="$1"
platform="$2"
sha="$3"
app="ShotCubby"

if gh release view "$tag" >/dev/null 2>&1; then
  exit 0
fi

mkdir -p seed
gh release download --dir seed \
  --pattern "$app.dmg" --pattern "$app-Setup.exe" --pattern "$app.msi" --pattern latest.json --pattern appcast.xml \
  || echo "No previous release to carry files over from."

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
  --target "$sha" --title "$tag" --notes-file notes.md --generate-notes
