#!/bin/bash
#
# Runs on the cPanel server from cron (every 10 minutes):
#   1. clones or fast-forwards the GitHub repository
#   2. mirrors every DMG listed in the appcast from GitHub Releases into /downloads
#   3. deploys website/ to the document root once all downloads are in place
#
# cron line (cPanel → Cron Jobs):
#   */10 * * * * /bin/bash -c 'export PATH=/usr/local/cpanel/3rdparty/bin:/usr/local/bin:/usr/bin:/bin; [ -d "$HOME/repositories/isla" ] || git clone -q https://github.com/Kyros-Solutions-RD/isla.git "$HOME/repositories/isla"; /bin/bash "$HOME/repositories/isla/scripts/server/sync.sh"' >> "$HOME/isla-sync.log" 2>&1
#
set -uo pipefail
export PATH="/usr/local/cpanel/3rdparty/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

REPO="${ISLA_REPO:-$HOME/repositories/isla}"
DOCROOT="${ISLA_DOCROOT:-$HOME/isla.kyrosrd.com}"
GITHUB="https://github.com/Kyros-Solutions-RD/isla"
LOCK="$HOME/.isla-sync.lock"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

# Single instance.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then rmdir "$LOCK"; mkdir "$LOCK"; else exit 0; fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

[ -d "$REPO/.git" ] || git clone -q "$GITHUB.git" "$REPO" || { log "clone failed"; exit 1; }
cd "$REPO" || exit 1
git fetch -q origin main || { log "fetch failed"; exit 1; }
git reset -q --hard origin/main
HEAD_SHA="$(git rev-parse --short HEAD)"

mkdir -p "$DOCROOT/downloads"

# Mirror every version referenced by the appcast.
missing=0
for version in $(grep -o 'downloads/Isla-[0-9][0-9.]*\.dmg' website/updates/appcast.xml | sed 's#downloads/Isla-##; s#\.dmg##' | sort -u); do
  target="$DOCROOT/downloads/Isla-$version.dmg"
  [ -s "$target" ] && continue
  log "mirroring Isla $version"
  if curl -fsSL --retry 3 -o "$target.part" "$GITHUB/releases/download/v$version/Isla-$version.dmg"; then
    mv "$target.part" "$target"
  else
    rm -f "$target.part"
    missing=1
    log "Isla $version is not on GitHub Releases yet"
  fi
done

# The newest version becomes downloads/Isla.dmg.
latest="$(grep -o '<sparkle:shortVersionString>[^<]*' website/updates/appcast.xml | head -1 | sed 's/.*>//')"
if [ -n "$latest" ] && [ -s "$DOCROOT/downloads/Isla-$latest.dmg" ]; then
  if ! cmp -s "$DOCROOT/downloads/Isla-$latest.dmg" "$DOCROOT/downloads/Isla.dmg"; then
    cp "$DOCROOT/downloads/Isla-$latest.dmg" "$DOCROOT/downloads/Isla.dmg"
  fi
fi

if [ "$missing" -ne 0 ]; then
  log "waiting for release assets; website not deployed yet ($HEAD_SHA)"
  exit 0
fi

if [ "$(cat "$DOCROOT/.deployed" 2>/dev/null)" != "$HEAD_SHA" ]; then
  cp -R website/. "$DOCROOT/"
  echo "$HEAD_SHA" > "$DOCROOT/.deployed"
  log "deployed $HEAD_SHA"
fi
