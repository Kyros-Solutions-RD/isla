#!/usr/bin/env bash
#
# Publishes a new version of Isla end to end:
#   1. bumps the version and builds a universal, signed DMG
#   2. signs the DMG for Sparkle and adds it to the appcast
#   3. commits, tags and pushes to GitHub, and creates a GitHub Release
#   4. waits until the cPanel server (cron, scripts/server/sync.sh) mirrors the
#      DMG and publishes the new appcast on isla.kyrosrd.com
#
# usage: ./scripts/release.sh 1.1.0
#
# Release notes come from the matching "## 1.1.0" section of CHANGELOG.md.
#
set -euo pipefail
cd "$(dirname "$0")/.."
ISLA_DOMAIN="${ISLA_DOMAIN:-isla.kyrosrd.com}"

VERSION="${1:?usage: release.sh <version>}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ Version must look like 1.2.3"; exit 1; }
command -v gh >/dev/null || { echo "✗ Install the GitHub CLI (brew install gh) and run gh auth login"; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "✗ Commit or stash your changes first"; exit 1; }

SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*SourcePackages/artifacts/sparkle/Sparkle/bin" -type d 2>/dev/null | head -1)"
if [ -z "$SPARKLE_BIN" ]; then
  xcodebuild -resolvePackageDependencies -project Isla.xcodeproj -scheme Isla >/dev/null
  SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*SourcePackages/artifacts/sparkle/Sparkle/bin" -type d | head -1)"
fi

# 1. Version
BUILD=$(( $(sed -n 's/^    CURRENT_PROJECT_VERSION: "\([0-9]*\)"/\1/p' project.yml) + 1 ))
sed -i '' "s/^    MARKETING_VERSION: \".*\"/    MARKETING_VERSION: \"${VERSION}\"/" project.yml
sed -i '' "s/^    CURRENT_PROJECT_VERSION: \".*\"/    CURRENT_PROJECT_VERSION: \"${BUILD}\"/" project.yml
echo "› Isla ${VERSION} (build ${BUILD})"

NOTES="$(mktemp -t isla-notes)"
trap 'rm -f "${NOTES:?}"' EXIT
awk -v v="$VERSION" '/^## /{p = index($0, v) > 0; next} p' CHANGELOG.md > "$NOTES"
[ -s "$NOTES" ] || echo "- Improvements and fixes." > "$NOTES"

./scripts/build-dmg.sh
DMG="dist/Isla-${VERSION}.dmg"

# 2. Sparkle signature and appcast
SIGNATURE_LINE="$("$SPARKLE_BIN/sign_update" --account isla "$DMG")"
SIGNATURE="$(echo "$SIGNATURE_LINE" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
LENGTH="$(echo "$SIGNATURE_LINE" | sed -n 's/.*length="\([0-9]*\)".*/\1/p')"
python3 -I scripts/lib/appcast.py website/updates/appcast.xml "$VERSION" "$BUILD" \
  "https://${ISLA_DOMAIN}/downloads/Isla-${VERSION}.dmg" "$SIGNATURE" "$LENGTH" "$NOTES"

# 3. GitHub: the release (with the DMG) exists before the appcast that points to it.
git add project.yml Isla.xcodeproj website/updates/appcast.xml
git commit -q -m "Release ${VERSION}"
git tag -a "v${VERSION}" -m "Isla ${VERSION}"
git push -q origin "v${VERSION}"
gh release create "v${VERSION}" "$DMG" "dist/Isla.dmg" --title "Isla ${VERSION}" --notes-file "$NOTES" --verify-tag
git push -q origin main

# 4. The server picks it up within ~10 minutes.
echo "› Waiting for https://${ISLA_DOMAIN} to publish ${VERSION} (cron sync)…"
for _ in $(seq 1 80); do
  if curl -fsS --max-time 15 "https://${ISLA_DOMAIN}/updates/appcast.xml" 2>/dev/null | grep -q "<sparkle:shortVersionString>${VERSION}<"; then
    echo "✓ Isla ${VERSION} is live:"
    echo "  https://${ISLA_DOMAIN}/downloads/Isla.dmg"
    echo "  https://github.com/Kyros-Solutions-RD/isla/releases/tag/v${VERSION}"
    exit 0
  fi
  sleep 15
done
echo "  Not live yet. Check ~/isla-sync.log on the server; the GitHub Release is already published."
