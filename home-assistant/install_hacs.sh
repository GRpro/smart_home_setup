#!/usr/bin/env bash
# Download HACS into the Home Assistant config (Docker Container install).
# Docs: https://hacs.xyz/docs/use/download/download/
#
# Note: Home Assistant 2026.11+ ships a native Marketplace and the official
# installer refuses to install HACS. Use Settings → Devices & services →
# Marketplace instead on those versions.
#
# After a successful install on older HA: restart, then Settings → Devices &
# services → Add integration → HACS (GitHub account required for first setup).

set -euo pipefail

CONTAINER="${HACS_HA_CONTAINER:-homeassistant}"

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "[ERROR] Container '$CONTAINER' not found. Start the stack (./start.sh) first."
  exit 1
fi

ha_version="$(docker exec "$CONTAINER" cat /config/.HA_VERSION 2>/dev/null || true)"
if [[ "$ha_version" =~ ^2026\.(1[1-9]|[2-9][0-9]) ]] || [[ "$ha_version" =~ ^202[7-9]\. ]]; then
  echo "[INFO] Home Assistant $ha_version includes the native Marketplace."
  echo "       HACS custom integration is not supported on 2026.11+."
  echo "       Use: Settings → Devices & services → Marketplace"
  echo "       Docs: https://www.home-assistant.io/integrations/marketplace"
  exit 0
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
