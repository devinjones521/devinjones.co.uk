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
ROOT="/var/www/devinjones"
DEST="$ROOT/index.html"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> building"
powershell -NoProfile -ExecutionPolicy Bypass -File "$HERE/build.ps1"

echo "==> uploading"
scp -i "$KEY" -q "$HERE/index.html" "$HOST:$DEST"
# static/ is flattened into the webroot: the icons, the manifest and the share card
# are referenced from the page as absolute paths (/icon.svg, /og.png), and iOS looks
# for /apple-touch-icon.png at the root whatever the page says.
scp -i "$KEY" -q "$HERE"/static/* "$HOST:$ROOT/"
ssh -i "$KEY" "$HOST" "chown -R www-data:www-data $ROOT"

echo "==> verifying"
code=$(curl -s -o /dev/null -w '%{http_code}' https://devinjones.co.uk/ || true)
echo "https://devinjones.co.uk/ -> ${code:-unreachable}"
[ "$code" = "200" ] || echo "WARNING: expected 200. Check DNS and the certificate."

# The share card is the one asset that fails silently: the page looks perfect while
# every link preview comes out blank, and the crawlers cache the failure.
for f in og.png icon.svg manifest.json apple-touch-icon.png; do
  c=$(curl -s -o /dev/null -w '%{http_code}' "https://devinjones.co.uk/$f" || true)
  echo "  /$f -> ${c:-unreachable}"
  [ "$c" = "200" ] || echo "  WARNING: /$f is not being served."
done
