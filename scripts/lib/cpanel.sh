#!/usr/bin/env bash
#
# Shared helpers for the cPanel UAPI.
#
# Credentials are read from ~/.config/isla/cpanel.env (or $ISLA_CPANEL_ENV):
#   CPANEL_HOST=kyrosrd.com
#   CPANEL_USER=neetjbte
#   CPANEL_TOKEN=<API token from cPanel → Security → Manage API Tokens>
#
# The token never leaves this machine except in the Authorization header sent
# to your own cPanel server, and it is never printed.

ISLA_DOMAIN="${ISLA_DOMAIN:-isla.kyrosrd.com}"
ISLA_ROOT_DOMAIN="${ISLA_ROOT_DOMAIN:-kyrosrd.com}"
ISLA_SUBDOMAIN="${ISLA_SUBDOMAIN:-isla}"
ISLA_REPO_URL="${ISLA_REPO_URL:-https://github.com/Kyros-Solutions-RD/isla.git}"

CPANEL_CONFIG="${ISLA_CPANEL_ENV:-$HOME/.config/isla/cpanel.env}"
if [ -f "$CPANEL_CONFIG" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$CPANEL_CONFIG"
  set +a
fi
CPANEL_HOST="${CPANEL_HOST:-kyrosrd.com}"
CPANEL_PORT="${CPANEL_PORT:-2083}"
CPANEL_USER="${CPANEL_USER:-neetjbte}"
CPANEL_HOME="${CPANEL_HOME:-/home/$CPANEL_USER}"
ISLA_REPO_ROOT="${ISLA_REPO_ROOT:-$CPANEL_HOME/repositories/isla}"

cpanel_require_token() {
  if [ -z "${CPANEL_TOKEN:-}" ]; then
    echo "✗ Missing CPANEL_TOKEN." >&2
    echo "  Create a token in cPanel → Security → Manage API Tokens and save it in $CPANEL_CONFIG:" >&2
    echo "    CPANEL_HOST=$CPANEL_HOST" >&2
    echo "    CPANEL_USER=$CPANEL_USER" >&2
    echo "    CPANEL_TOKEN=…" >&2
    exit 1
  fi
}

# uapi Module function key=value …  → prints the raw JSON response
uapi() {
  cpanel_require_token
  local module=$1 function=$2
  shift 2
  local args=()
  for pair in "$@"; do args+=(--data-urlencode "$pair"); done
  curl -sS --max-time 120 -G \
    -H "Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}" \
    "https://${CPANEL_HOST}:${CPANEL_PORT}/execute/${module}/${function}" \
    ${args[@]+"${args[@]}"}
}

# Reads a UAPI response on stdin, prints its data (or errors) and sets the exit code.
uapi_result() {
  python3 -I -c '
import json, sys
raw = sys.stdin.read()
try:
    response = json.loads(raw)
except ValueError:
    print("✗ Unexpected response from cPanel: " + raw[:300].replace("\n", " "))
    sys.exit(1)
if response.get("status") == 1:
    print(json.dumps(response.get("data"), ensure_ascii=False))
    sys.exit(0)
print("✗ " + "; ".join(response.get("errors") or ["Unknown cPanel error"]))
sys.exit(1)
'
}

# cpanel_upload <remote dir relative to home> <file>…
cpanel_upload() {
  cpanel_require_token
  local dir=$1
  shift
  local files=() index=1
  for file in "$@"; do
    files+=(-F "file-${index}=@${file}")
    index=$((index + 1))
  done
  curl -sS --max-time 600 \
    -H "Authorization: cpanel ${CPANEL_USER}:${CPANEL_TOKEN}" \
    -F "dir=${dir}" -F "overwrite=1" "${files[@]}" \
    "https://${CPANEL_HOST}:${CPANEL_PORT}/execute/Fileman/upload_files"
}

# Prints the document root of the Isla domain (absolute path).
isla_document_root() {
  uapi DomainInfo single_domain_data "domain=${ISLA_DOMAIN}" | python3 -I -c '
import json, sys
data = (json.load(sys.stdin).get("data") or {})
print(data.get("documentroot", ""))
'
}
