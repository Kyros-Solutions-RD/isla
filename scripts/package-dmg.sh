#!/usr/bin/env bash
#
# Packages an Isla.app into the designed installer disk image:
# illustrated background, Isla on the left, the Applications link on the right,
# the app icon as the volume icon.
#
#   ./scripts/package-dmg.sh path/to/Isla.app dist/Isla-1.0.0.dmg
#
# The window layout is set by Finder (AppleScript). The first run asks once for
# permission to control Finder. Without it the disk image is still built, with
# the default layout.
#
# Background artwork: design/dmg/background.png and background@2x.png, made by
# scripts/lib/dmg-background.swift. Icon positions here must match that script.
#
set -euo pipefail

APP="${1:?usage: package-dmg.sh <Isla.app> <output.dmg>}"
DMG="${2:?usage: package-dmg.sh <Isla.app> <output.dmg>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ART="$ROOT/design/dmg"
VOLUME="Isla"

# Window: 690×460 points of content. Finder's bounds include the title bar.
WINDOW_LEFT=200; WINDOW_TOP=140; WINDOW_WIDTH=690; WINDOW_HEIGHT=460; TITLE_BAR=28
APP_X=178; APP_Y=228; APPLICATIONS_X=512; APPLICATIONS_Y=228

[ -d "$APP" ] || { echo "✗ $APP not found"; exit 1; }
if [ -d "/Volumes/$VOLUME" ]; then
  echo "✗ A volume named \"$VOLUME\" is already mounted. Eject it and run again."
  exit 1
fi

WORK="$(mktemp -d -t isla-dmg)"
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
  rm -rf "${WORK:?}"
}
trap cleanup EXIT

STAGING="$WORK/staging"
mkdir -p "$STAGING/.background"
ditto "$APP" "$STAGING/Isla.app"
ln -s /Applications "$STAGING/Applications"
tiffutil -cathidpicheck "$ART/background.png" "$ART/background@2x.png" -out "$STAGING/.background/background.tiff" 2>/dev/null

RW="$WORK/rw.dmg"
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW"
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
[ -n "$MOUNT" ] || { echo "✗ Could not mount the disk image"; exit 1; }

if ! osascript >/dev/null <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME"
    open
    set theWindow to container window
    set current view of theWindow to icon view
    set toolbar visible of theWindow to false
    set statusbar visible of theWindow to false
    set bounds of theWindow to {$WINDOW_LEFT, $WINDOW_TOP, $((WINDOW_LEFT + WINDOW_WIDTH)), $((WINDOW_TOP + WINDOW_HEIGHT + TITLE_BAR))}
    set viewOptions to icon view options of theWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set label position of viewOptions to bottom
    set shows item info of viewOptions to false
    set shows icon preview of viewOptions to false
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "Isla.app" of theWindow to {$APP_X, $APP_Y}
    set position of item "Applications" of theWindow to {$APPLICATIONS_X, $APPLICATIONS_Y}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
then
  echo "  ! Finder layout skipped (allow your terminal to control Finder in System Settings › Privacy & Security › Automation)"
fi

# Let Finder write .DS_Store, then seal the volume.
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -f "$MOUNT/.DS_Store" ] && break; sleep 0.5; done

# Volume icon. Added after the Finder step, which drops it on current macOS.
cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "$MOUNT" 2>/dev/null || echo "  ! Could not set the volume icon (SetFile comes with the Xcode command line tools)"
rm -rf "$MOUNT/.fseventsd" "$MOUNT/.Trashes" 2>/dev/null || true
chmod -Rf go-w "$MOUNT" 2>/dev/null || true
sync
hdiutil detach "$MOUNT" -quiet || hdiutil detach "$MOUNT" -quiet -force
MOUNT=""

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"
hdiutil convert "$RW" -quiet -format UDZO -imagekey zlib-level=9 -o "$DMG"
if [ -n "${SIGN_IDENTITY:-}" ] && [ "$SIGN_IDENTITY" != "-" ]; then
  codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi
echo "✓ $DMG"
