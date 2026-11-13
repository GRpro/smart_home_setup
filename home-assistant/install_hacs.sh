#!/usr/bin/env bash
# Download HACS into the Home Assistant config (Docker Container install).
# Docs: https://hacs.xyz/docs/use/download/download/
#
# After this script: restart HA, then Settings → Devices & services → Add
# integration → HACS (GitHub account required for first setup).

set -euo pipefail

CONTAINER="${HACS_HA_CONTAINER:-homeassistant}"

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "[ERROR] Container '$CONTAINER' not found. Start the stack (./start.sh) first."
  exit 1
fi

if docker exec "$CONTAINER" test -f /config/custom_components/hacs/manifest.json 2>/dev/null; then
  echo "[OK] HACS already present under /config/custom_components/hacs"
  echo "Restart Home Assistant if you just added it, then add the HACS integration in the UI."
  exit 0
fi

echo "[hacs] Downloading HACS into $CONTAINER:/config (get.hacs.xyz)..."
if docker exec "$CONTAINER" which wget >/dev/null 2>&1; then
  docker exec "$CONTAINER" sh -c 'cd /config && wget -O - https://get.hacs.xyz | bash -'
elif docker exec "$CONTAINER" which curl >/dev/null 2>&1; then
  docker exec "$CONTAINER" sh -c 'cd /config && curl -fsSL https://get.hacs.xyz | bash -'
else
  echo "[ERROR] Neither wget nor curl available in $CONTAINER"
  exit 1
fi

if ! docker exec "$CONTAINER" test -f /config/custom_components/hacs/manifest.json; then
  echo "[ERROR] HACS download finished but manifest.json is missing."
  exit 1
fi

echo "[OK] HACS installed. Restarting Home Assistant..."
docker restart "$CONTAINER" >/dev/null

echo "[OK] Next: open Home Assistant → Settings → Devices & services → Add integration → HACS"
echo "     You will need a GitHub account to authorize HACS on first setup."
