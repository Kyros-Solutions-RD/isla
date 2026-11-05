#!/usr/bin/env bash
#
# Builds a Release copy of Isla and packages it as dist/Isla.dmg.
#
#   ./scripts/build-dmg.sh            # ad-hoc signed (community build)
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ISLA_TEAM_ID=TEAMID ./scripts/build-dmg.sh
#
# With a Developer ID the app keeps the hardened runtime, gets a secure timestamp and no
# debugging entitlement, and the disk image is signed too. scripts/release.sh then
# notarizes and staples it when NOTARY_PROFILE is set (see CONTRIBUTING.md).
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# ".noindex" keeps this build out of Spotlight and Launchpad, so it never shows up as a second Isla.
BUILD_DIR="${BUILD_DIR:-$HOME/Library/Developer/Xcode/DerivedData/Isla-release.noindex}"
DIST="${DIST:-$ROOT/dist}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
export SIGN_IDENTITY

cd "$ROOT"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --quiet
fi

echo "› Building Isla (Release)…"
BUILD_ARGS=(
  -project Isla.xcodeproj
  -scheme Isla
  -configuration Release
  -derivedDataPath "$BUILD_DIR"
  -destination "generic/platform=macOS"
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY"
  -skipPackagePluginValidation
  -skipMacroValidation
  build
)
if [ "$SIGN_IDENTITY" = "-" ]; then
  # Ad-hoc signatures carry no Team ID, so the hardened runtime's library validation
  # refuses the embedded Sparkle.framework and the app dies at launch. Only notarized
  # (Developer ID) builds need the hardened runtime; they keep it.
  BUILD_ARGS+=(ENABLE_HARDENED_RUNTIME=NO)
else
  : "${ISLA_TEAM_ID:?Set ISLA_TEAM_ID to the Team ID of the Developer ID certificate}"
  BUILD_ARGS+=(DEVELOPMENT_TEAM="$ISLA_TEAM_ID" ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
               "OTHER_CODE_SIGN_FLAGS=--timestamp")
fi
if command -v xcbeautify >/dev/null 2>&1; then
  xcodebuild "${BUILD_ARGS[@]}" | xcbeautify
else
  xcodebuild "${BUILD_ARGS[@]}" -quiet
fi

APP="$BUILD_DIR/Build/Products/Release/Isla.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"

if [ "$SIGN_IDENTITY" = "-" ]; then
  # An ad-hoc signature's designated requirement is the build's own hash, so macOS
  # treats every update as a different app and forgets Accessibility and other grants.
  # Pin it to the bundle identifier instead; nested frameworks keep their signatures.
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")"
  codesign --force --sign - --preserve-metadata=entitlements,flags,runtime \
    --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP"
fi

# Never package a build that cannot start (missing or rejected frameworks, signing).
echo "› Checking that Isla $VERSION launches…"
codesign --verify --deep --strict "$APP"
LAUNCH_OUTPUT="$(perl -e 'alarm 60; exec @ARGV' /usr/bin/env ISLA_LAUNCH_CHECK=1 "$APP/Contents/MacOS/Isla" 2>&1 || true)"
if ! grep -q "isla-launch-check-ok" <<<"$LAUNCH_OUTPUT"; then
  echo "✗ The built app does not launch:"
  echo "$LAUNCH_OUTPUT" | tail -20
  exit 1
fi

echo "› Packaging Isla $VERSION…"
DMG="$DIST/Isla-$VERSION.dmg"
"$ROOT/scripts/package-dmg.sh" "$APP" "$DMG"
cp -f "$DMG" "$DIST/Isla.dmg"

