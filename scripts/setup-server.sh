#!/usr/bin/env bash
#
# One-time setup of isla.kyrosrd.com on the cPanel server:
#   1. creates the subdomain
#   2. requests a free AutoSSL certificate
#   3. clones the GitHub repository with cPanel Git Version Control
#   4. deploys the website (.cpanel.yml copies website/ to the document root)
#
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib/cpanel.sh

echo "› Checking ${ISLA_DOMAIN}…"
domains=$(uapi DomainInfo list_domains | uapi_result)
if echo "$domains" | python3 -I -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '${ISLA_DOMAIN}' in d.get('sub_domains', []) + d.get('addon_domains', []) else 1)"; then
  echo "  ${ISLA_DOMAIN} already exists."
else
  echo "› Creating ${ISLA_DOMAIN}…"
  if ! uapi SubDomain addsubdomain "domain=${ISLA_SUBDOMAIN}" "rootdomain=${ISLA_ROOT_DOMAIN}" "dir=${ISLA_DOMAIN}" | uapi_result; then
    echo "  Retrying inside public_html…"
    uapi SubDomain addsubdomain "domain=${ISLA_SUBDOMAIN}" "rootdomain=${ISLA_ROOT_DOMAIN}" "dir=public_html/${ISLA_DOMAIN}" | uapi_result
  fi
fi

docroot=$(isla_document_root)
echo "  Document root: ${docroot}"
if ! grep -q "DEPLOYPATH=${docroot}/" .cpanel.yml; then
  echo "› Updating .cpanel.yml to deploy into ${docroot}"
  sed -i '' "s#export DEPLOYPATH=.*#export DEPLOYPATH=${docroot}/#" .cpanel.yml
  echo "  Commit and push .cpanel.yml before deploying."
fi

echo "› Requesting an SSL certificate (AutoSSL)…"
uapi SSL start_autossl_check | uapi_result >/dev/null || echo "  AutoSSL could not start now; cPanel retries automatically."

echo "› Connecting cPanel Git to ${ISLA_REPO_URL}…"
repos=$(uapi VersionControl retrieve | uapi_result)
if echo "$repos" | grep -q "\"repository_root\": \"${ISLA_REPO_ROOT}\""; then
  echo "  Repository already connected at ${ISLA_REPO_ROOT}."
else
  uapi VersionControl create "type=git" "name=Isla" "repository_root=${ISLA_REPO_ROOT}" \
    "source_repository={\"remote_name\":\"origin\",\"url\":\"${ISLA_REPO_URL}\"}" | uapi_result >/dev/null
  echo "  Cloning… (cPanel does this in the background)"
  for _ in $(seq 1 30); do
    sleep 4
    state=$(uapi VersionControl retrieve | uapi_result)
    if echo "$state" | python3 -I -c "
import json, sys
repos = json.load(sys.stdin)
repo = next((r for r in repos if r.get('repository_root') == '${ISLA_REPO_ROOT}'), None)
sys.exit(0 if repo and repo.get('last_update') else 1)"; then
      break
    fi
  done
fi

./scripts/deploy-site.sh
echo "✓ https://${ISLA_DOMAIN} is set up."
