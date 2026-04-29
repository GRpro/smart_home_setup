#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHIRPSTACK_DIR="$SCRIPT_DIR/chirpstack-docker"
HOME_ASSISTANT_DIR="$SCRIPT_DIR/home-assistant"

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif docker-compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "[ERROR] Neither 'docker compose' nor 'docker-compose' found."
  exit 1
fi

echo "[stop] Stopping home-assistant stack..."
"${COMPOSE_CMD[@]}" -f "$HOME_ASSISTANT_DIR/docker-compose.yml" stop

echo "[stop] Stopping chirpstack-docker stack..."
"${COMPOSE_CMD[@]}" -f "$CHIRPSTACK_DIR/docker-compose.yml" stop

echo "[OK] Both stacks are stopped."
