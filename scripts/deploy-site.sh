#!/usr/bin/env bash
#
# Pulls the latest commit from GitHub into cPanel and deploys the website.
#
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib/cpanel.sh

echo "› Pulling main from GitHub into ${ISLA_REPO_ROOT}…"
uapi VersionControl update "repository_root=${ISLA_REPO_ROOT}" "branch=main" | uapi_result >/dev/null

echo "› Deploying ${ISLA_DOMAIN}…"
uapi VersionControlDeployment create "repository_root=${ISLA_REPO_ROOT}" | uapi_result >/dev/null

for _ in $(seq 1 20); do
  sleep 3
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${ISLA_DOMAIN}/updates/appcast.xml" || true)
  if [ "$status" = "200" ]; then
    echo "✓ Live at https://${ISLA_DOMAIN}"
    exit 0
  fi
done
echo "  Deployment queued. The site may take a moment (or SSL may still be issuing)."
