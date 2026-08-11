#!/usr/bin/env bash
# Build, then push the page to the Hetzner box that serves devinjones.co.uk.
#
#   ./deploy.sh
#
# The box also serves a client's live site, so this never touches nginx config
# and never reloads the service. It copies one static file into its own webroot.

set -euo pipefail

HOST="root@204.168.148.150"
KEY="$HOME/.ssh/id_ed25519"
DEST="/var/www/devinjones/index.html"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> building"
powershell -NoProfile -ExecutionPolicy Bypass -File "$HERE/build.ps1"

echo "==> uploading"
scp -i "$KEY" -q "$HERE/index.html" "$HOST:$DEST"
ssh -i "$KEY" "$HOST" "chown www-data:www-data $DEST"

echo "==> verifying"
code=$(curl -s -o /dev/null -w '%{http_code}' https://devinjones.co.uk/ || true)
echo "https://devinjones.co.uk/ -> ${code:-unreachable}"
[ "$code" = "200" ] || echo "WARNING: expected 200. Check DNS and the certificate."
